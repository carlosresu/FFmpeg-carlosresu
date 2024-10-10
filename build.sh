#!/bin/bash
set -e  # Exit immediately if any command fails

git submodule update --init --recursive

### Platform and Architecture Detection ###
PLATFORM=$(uname)
ARCH=$(uname -m)

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

    # Install essential dependencies via Homebrew
    echo "Installing macOS dependencies..."
    brew install nasm yasm pkg-config automake autoconf cmake libtool texinfo git
    brew install zlib x264 x265 fdk-aac libvpx libvorbis libass libbluray opencore-amr opus aom dav1d frei0r theora libvidstab libvmaf rav1e rubberband sdl2 snappy speex srt tesseract two-lame xvid xz fontconfig frei0r fribidi gnutls lame libsoxr openssl

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

    # Set paths
    PREFIX="/opt/ffmpeg_build"
    PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

    # Ensure directories exist
    sudo mkdir -p $PREFIX

### Linux Setup ###
elif [[ "$PLATFORM" == "Linux" ]]; then
    echo "Setting up for Linux..."

    # Install essential dependencies via apt (for Debian/Ubuntu-based distros)
    sudo apt update
    sudo apt install -y nasm yasm pkg-config automake autoconf cmake libtool texinfo git zlib1g-dev libx264-dev libx265-dev libvpx-dev libvorbis-dev libass-dev libbluray-dev libopencore-amrnb-dev libopencore-amrwb-dev libopus-dev libaom-dev libdav1d-dev libtheora-dev libvidstab-dev libvmaf-dev librubberband-dev sdl2-dev libsnappy-dev libspeex-dev libsrt-dev libtesseract-dev libsoxr-dev libtwolame-dev libxvidcore-dev libzmq3-dev libzimg-dev librabbitmq-dev libssl-dev libfdk-aac-dev

    # Install additional libraries and headers
    sudo apt install -y zlib1g-dev libssl-dev

    # Set up native optimization for Linux
    OPT_FLAGS="-O3 -ffast-math -ftree-vectorize -march=native"

    # Set paths
    PREFIX="/opt/ffmpeg_build"
    PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

    # Ensure directories exist
    sudo mkdir -p $PREFIX

### Windows Setup (via MSYS2) ###
elif [[ "$PLATFORM" == "MINGW"* || "$PLATFORM" == "MSYS"* || "$PLATFORM" == "CYGWIN"* ]]; then
    echo "Setting up for Windows (via MSYS2)..."

    # Install MSYS2 dependencies
    pacman -Syu --noconfirm
    pacman -S --noconfirm base-devel mingw-w64-x86_64-toolchain mingw-w64-x86_64-cmake mingw-w64-x86_64-nasm mingw-w64-x86_64-yasm mingw-w64-x86_64-pkg-config git mingw-w64-x86_64-libvpx mingw-w64-x86_64-x264 mingw-w64-x86_64-x265 mingw-w64-x86_64-fdk-aac mingw-w64-x86_64-opus mingw-w64-x86_64-libtheora mingw-w64-x86_64-dav1d mingw-w64-x86_64-vorbis mingw-w64-x86_64-ass mingw-w64-x86_64-vidstab mingw-w64-x86_64-sdl2

    # Set up native optimization for Windows
    OPT_FLAGS="-O3 -ffast-math -ftree-vectorize -march=native"

    # Set paths
    PREFIX="/mingw64/opt/ffmpeg_build"
    PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

    # Ensure directories exist
    sudo mkdir -p $PREFIX

else
    echo "Unsupported platform: $PLATFORM"
    exit 1
fi

### Common Configuration and Build ###
# Configuration flags
CONFIG_FLAGS="--prefix=$PREFIX"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-gpl --enable-version3 --enable-nonfree"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-static --enable-shared --enable-pic"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-lto --enable-optimizations"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-hardcoded-tables --enable-swscale-alpha"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-postproc --enable-swresample"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-pthreads --disable-decklink"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-runtime-cpudetect --disable-debug"

# Video and Audio Codecs
CONFIG_FLAGS="$CONFIG_FLAGS --enable-libx264 --enable-libx265 --enable-libvpx"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-libmp3lame --enable-libopus --enable-libvorbis"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-libtheora --enable-libass --enable-libbluray"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-libfdk-aac --enable-libfreetype --enable-libfontconfig"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-libfribidi --enable-libvidstab --enable-librubberband"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-librtmp --enable-libsoxr --enable-libtwolame"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-libxvid --enable-libzmq --enable-libzimg"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-librabbitmq --enable-libsnappy --enable-libsrt"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-libspeex --enable-libtesseract --enable-libvmaf"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-libaom --enable-libdav1d --enable-libsvtav1"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-libaribb24 --enable-libmysofa --enable-decklink"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-openssl --enable-sdl2"

# Hardware acceleration
CONFIG_FLAGS="$CONFIG_FLAGS --enable-videotoolbox --enable-vaapi --enable-vdpau"
CONFIG_FLAGS="$CONFIG_FLAGS --enable-opencl --enable-opengl"

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

# Configure FFmpeg with all features
./configure --prefix="$PREFIX" $CONFIG_FLAGS

# Compile using all CPU cores
make -j$(nproc || sysctl -n hw.ncpu)

# Install
make install

# Success message
echo "FFmpeg built successfully with all features and optimizations, installed to $PREFIX"