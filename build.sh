#!/bin/bash
set -e  # Exit immediately if any command fails

git submodule update --init --recursive

### Platform and Architecture Detection ###
PLATFORM=$(uname)
ARCH=$(uname -m)

### Default flags
CONFIG_FLAGS="--enable-gpl --enable-version3 --enable-nonfree --enable-static --enable-shared --enable-pic"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-lto --enable-optimizations --enable-hardcoded-tables"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-swscale-alpha --enable-postproc --enable-swresample"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-pthreads --disable-decklink --enable-runtime-cpudetect --disable-debug"

### macOS Setup ###
if [[ "$PLATFORM" == "Darwin" ]]; then
    echo "Setting up for macOS..."

    # Update and install Homebrew if not installed
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "Homebrew found. Updating Homebrew..."
        brew update
    fi

    # Function to install Homebrew packages only if they aren't already installed
    install_if_missing() {
        for package in "$@"; do
            if ! brew list --formula | grep -q "^$package\$"; then
                echo "Installing $package..."
                brew install "$package"
            else
                echo "$package is already installed."
            fi
        done
    }

    # Install essential dependencies via Homebrew
    echo "Installing macOS dependencies..."
    install_if_missing nasm yasm pkg-config automake autoconf cmake libtool texinfo git
    install_if_missing zlib x264 x265 fdk-aac libvpx libvorbis libass libbluray aom dav1d opus

    # Skip unavailable dependencies or provide manual installation instructions
    echo "Note: You'll need to install 'librtmp' and 'libzmq' manually as they are not available in Homebrew."

    # Check for manual installation of librtmp and libzmq
    if ! brew list --formula | grep -q "librtmp"; then
        echo "librtmp not found, please install it manually:"
        echo "git clone https://git.ffmpeg.org/rtmpdump.git"
        echo "cd rtmpdump/librtmp && make && sudo make install"
    fi

    if ! brew list --formula | grep -q "libzmq"; then
        echo "libzmq not found, please install it manually:"
        echo "git clone https://github.com/zeromq/libzmq.git"
        echo "cd libzmq && ./autogen.sh && ./configure && make && sudo make install"
    fi

    # Set up native optimization for macOS
    OPT_FLAGS="-O3 -ffast-math -ftree-vectorize -march=native"

    # Set paths and include both Homebrew and custom install directories in PKG_CONFIG_PATH
    PREFIX="/usr/local/ffmpeg_build"
    export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:$PREFIX/lib/pkgconfig"

    # Manually include Homebrew's include and lib paths for necessary libraries
    export CFLAGS="-I/opt/homebrew/include $CFLAGS"
    export LDFLAGS="-L/opt/homebrew/lib $LDFLAGS"

    # Ensure directories exist
    sudo mkdir -p $PREFIX

    # Disable VAAPI and VDPAU for macOS
    VAAPI_FLAG=""
    VDPAU_FLAG=""

    # Disable OpenGL for macOS
    echo "Disabling OpenGL on macOS..."
    OPENGL_FLAG="--disable-opengl"

    # Set PATH for macOS
    echo "Adding FFmpeg to system PATH for macOS..."
    echo "export PATH=\"$PREFIX/bin:\$PATH\"" >> ~/.bash_profile
    source ~/.bash_profile

### Linux Setup ###
elif [[ "$PLATFORM" == "Linux" ]]; then
    echo "Setting up for Linux..."

    # Install essential dependencies via apt (for Debian/Ubuntu-based distros)
    sudo apt update
    sudo apt install -y nasm yasm pkg-config automake autoconf cmake libtool texinfo git zlib1g-dev libx264-dev libx265-dev libvpx-dev libvorbis-dev libass-dev libbluray-dev libopus-dev libaom-dev libdav1d-dev

    # Set up native optimization for Linux
    OPT_FLAGS="-O3 -ffast-math -ftree-vectorize -march=native"

    # Set paths and include both system-wide and custom install directories in PKG_CONFIG_PATH
    PREFIX="/usr/local/ffmpeg_build"
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PREFIX/lib/pkgconfig"

    # Ensure directories exist
    sudo mkdir -p $PREFIX

    # Enable VAAPI and VDPAU for Linux
    VAAPI_FLAG="--enable-vaapi"
    VDPAU_FLAG="--enable-vdpau"
    
    # Enable OpenGL for Linux
    OPENGL_FLAG="--enable-opengl"

    # Set PATH for Linux
    echo "Adding FFmpeg to system PATH for Linux..."
    echo "export PATH=\"$PREFIX/bin:\$PATH\"" >> ~/.bashrc
    source ~/.bashrc

### Windows Setup (via MSYS2) ###
elif [[ "$PLATFORM" == "MINGW"* || "$PLATFORM" == "MSYS"* || "$PLATFORM" == "CYGWIN"* ]]; then
    echo "Setting up for Windows (via MSYS2)..."

    # Install MSYS2 dependencies
    pacman -Syu --noconfirm
    pacman -S --noconfirm base-devel mingw-w64-x86_64-toolchain mingw-w64-x86_64-cmake mingw-w64-x86_64-nasm mingw-w64-x86_64-yasm mingw-w64-x86_64-pkg-config git mingw-w64-x86_64-libvpx mingw-w64-x86_64-x264 mingw-w64-x86_64-x265 mingw-w64-x86_64-fdk-aac mingw-w64-x86_64-opus mingw-w64-x86_64-dav1d mingw-w64-x86_64-vorbis

    # Set up native optimization for Windows
    OPT_FLAGS="-O3 -ffast-math -ftree-vectorize -march=native"

    # Set paths and include both MSYS2 and custom install directories in PKG_CONFIG_PATH
    PREFIX="/mingw64/opt/ffmpeg_build"
    export PKG_CONFIG_PATH="/mingw64/lib/pkgconfig:$PREFIX/lib/pkgconfig"

    # Ensure directories exist
    sudo mkdir -p $PREFIX

    # Disable VAAPI and VDPAU for Windows
    VAAPI_FLAG=""
    VDPAU_FLAG=""
    
    # Enable OpenGL for Windows
    OPENGL_FLAG="--enable-opengl"

    # Set PATH for Windows (MSYS2)
    echo "Adding FFmpeg to system PATH for Windows..."
    echo "export PATH=\"$PREFIX/bin:\$PATH\"" >> ~/.bash_profile
    source ~/.bash_profile

else
    echo "Unsupported platform: $PLATFORM"
    exit 1
fi

### Common Configuration and Build ###
# Add flags for Homebrew-installed libraries
CONFIG_FLAGS="$CONFIG_FLAGS --extra-cflags=$CFLAGS"
CONFIG_FLAGS="$CONFIG_FLAGS --extra-ldflags=$LDFLAGS"

# Video and Audio Codecs
CONFIG_FLAGS="$CONFIG_FLAGS --enable-libx264 --enable-libx265 --enable-libvpx --enable-libopus --enable-libvorbis"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-libfdk-aac --enable-libass --enable-libbluray --enable-libaom --enable-libdav1d"

# Hardware acceleration based on platform
CONFIG_FLAGS="$CONFIG_FLAGS --enable-videotoolbox $VAAPI_FLAG $VDPAU_FLAG $OPENGL_FLAG"

# Set environment variables
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH
export CFLAGS="$OPT_FLAGS"
export LDFLAGS="$OPT_FLAGS"
export PATH="$PREFIX/bin:$PATH"

# Change to FFmpeg directory
cd ~/moonlight-qt-carlosresu/FFmpeg-carlosresu

# Clean previous build
make clean || true
make distclean || true

echo "$CONFIG_FLAGS"
# Configure FFmpeg with all features
./configure --prefix="$PREFIX" $CONFIG_FLAGS

# Compile using all CPU cores
make -j$(nproc || sysctl -n hw.ncpu)

# Install
sudo make install

# Success message
echo "FFmpeg built successfully with all features and optimizations, installed to $PREFIX"

# Success message after PATH update
echo "FFmpeg path added to system PATH."