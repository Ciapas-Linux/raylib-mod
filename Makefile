#******************************************************************************
#
#  raylib makefile
#
#  Platforms supported:
#    PLATFORM_DESKTOP:  Windows (Win32, Win64)
#    PLATFORM_DESKTOP:  Linux (i386, x64)
#    PLATFORM_DESKTOP:  OSX/macOS (arm64, x86_64)
#    PLATFORM_DESKTOP:  FreeBSD, OpenBSD, NetBSD, DragonFly
#    PLATFORM_ANDROID:  Android (arm, i686, arm64, x86_64)
#    PLATFORM_RPI:      Raspberry Pi (Raspbian)
#    PLATFORM_DRM:      Linux native mode, including Raspberry Pi 4 with V3D fkms driver
#    PLATFORM_WEB:      HTML5 (Chrome, Firefox)
#
#  Many thanks to Milan Nikolic (@gen2brain) for implementing Android platform pipeline.
#  Many thanks to Emanuele Petriglia for his contribution on GNU/Linux pipeline.
#
#  Copyright (c) 2014-2019 Ramon Santamaria (@raysan5)
#
#  This software is provided "as-is", without any express or implied warranty.
#  In no event will the authors be held liable for any damages arising from
#  the use of this software.
#
#  Permission is granted to anyone to use this software for any purpose,
#  including commercial applications, and to alter it and redistribute it
#  freely, subject to the following restrictions:
#
#    1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software in a
#    product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
#
#    2. Altered source versions must be plainly marked as such, and must not
#    be misrepresented as being the original software.
#
#    3. This notice may not be removed or altered from any source distribution.
#
#******************************************************************************

# Please read the wiki to know how to compile raylib, because there are different methods.
# https://github.com/raysan5/raylib/wiki

.PHONY: all clean install uninstall

# Define required raylib variables
RAYLIB_VERSION        = 3.8.1
RAYLIB_API_VERSION    = 381

# Define raylib source code path
RAYLIB_SRC_PATH      ?= /home/$(USER)/raylib/src

# Define output directory for compiled library, defaults to src directory
# NOTE: If externally provided, make sure directory exists
RAYLIB_RELEASE_PATH  ?= $(RAYLIB_SRC_PATH)

# Library type used for raylib: STATIC (.a) or SHARED (.so/.dll)
RAYLIB_LIBTYPE       ?= STATIC

# Build mode for library: DEBUG or RELEASE
RAYLIB_BUILD_MODE    ?= DEBUG

# Build output name for the library
RAYLIB_LIB_NAME      ?= raylib

# Define resource file for DLL properties
RAYLIB_RES_FILE      ?= ./raylib.dll.rc.data

# Define raylib platform
# Options:  PLATFORM_DESKTOP, PLATFORM_RPI, PLATFORM_ANDROID, PLATFORM_WEB
PLATFORM             ?= PLATFORM_ANDROID

# Include raylib modules on compilation
# NOTE: Some programs like tools could not require those modules
RAYLIB_MODULE_AUDIO  ?= TRUE
RAYLIB_MODULE_MODELS ?= TRUE
RAYLIB_MODULE_RAYGUI ?= TRUE
RAYLIB_MODULE_PHYSAC ?= TRUE

#RAYLIB_MODULE_PNG ?= TRUE
#RAYLIB_MODULE_NET ?= TRUE


RAYLIB_MODULE_RAYGUI_PATH ?= /home/$(USER)/raygui-2.8/src/dae
RAYLIB_MODULE_PHYSAC_PATH ?= $(RAYLIB_SRC_PATH)/extras

#RAYLIB_MODULE_PNG_PATH ?= $(RAYLIB_SRC_PATH)/extras
#RAYLIB_MODULE_NET_PATH ?= $(RAYLIB_SRC_PATH)/extras

# Use external GLFW library instead of rglfw module
# TODO: Review usage of examples on Linux.
USE_EXTERNAL_GLFW    ?= FALSE

# Use Wayland display server protocol on Linux desktop
# by default it uses X11 windowing system
USE_WAYLAND_DISPLAY  ?= FALSE

# Use cross-compiler for PLATFORM_RPI
ifeq ($(PLATFORM),PLATFORM_RPI)
    USE_RPI_CROSS_COMPILER ?= FALSE
    ifeq ($(USE_RPI_CROSS_COMPILER),TRUE)
        RPI_TOOLCHAIN ?= C:/SysGCC/Raspberry
        RPI_TOOLCHAIN_SYSROOT ?= $(RPI_TOOLCHAIN)/arm-linux-gnueabihf/sysroot
    endif
endif

# Determine if the file has root access (only for installing raylib)
# "whoami" prints the name of the user that calls him (so, if it is the root
# user, "whoami" prints "root").
ROOT = $(shell whoami)

# By default we suppose we are working on Windows
HOST_PLATFORM_OS ?= WINDOWS

# Determine PLATFORM_OS in case PLATFORM_DESKTOP selected
ifeq ($(PLATFORM),PLATFORM_DESKTOP)
    # No uname.exe on MinGW!, but OS=Windows_NT on Windows!
    # ifeq ($(UNAME),Msys) -> Windows
    ifeq ($(OS),Windows_NT)
        PLATFORM_OS = WINDOWS
    else
        UNAMEOS = $(shell uname)
        ifeq ($(UNAMEOS),Linux)
            PLATFORM_OS = LINUX
        endif
        ifeq ($(UNAMEOS),FreeBSD)
            PLATFORM_OS = BSD
        endif
        ifeq ($(UNAMEOS),OpenBSD)
            PLATFORM_OS = BSD
        endif
        ifeq ($(UNAMEOS),NetBSD)
            PLATFORM_OS = BSD
        endif
        ifeq ($(UNAMEOS),DragonFly)
            PLATFORM_OS = BSD
        endif
        ifeq ($(UNAMEOS),Darwin)
            PLATFORM_OS = OSX
        endif
    endif
endif
ifeq ($(PLATFORM),PLATFORM_RPI)
    UNAMEOS = $(shell uname)
    ifeq ($(UNAMEOS),Linux)
        PLATFORM_OS = LINUX
    endif
endif
ifeq ($(PLATFORM),PLATFORM_DRM)
    UNAMEOS = $(shell uname)
    ifeq ($(UNAMEOS),Linux)
        PLATFORM_OS = LINUX
    endif
endif

# RAYLIB_SRC_PATH adjustment for different platforms.
# If using GNU make, we can get the full path to the top of the tree. Windows? BSD?
# Required for ldconfig or other tools that do not perform path expansion.
ifeq ($(PLATFORM),PLATFORM_DESKTOP)
    ifeq ($(PLATFORM_OS),LINUX)
        RAYLIB_PREFIX  ?= ..
        RAYLIB_SRC_PATH = $(realpath $(RAYLIB_PREFIX))
    endif
endif

ifeq ($(PLATFORM),PLATFORM_WEB)
    # Emscripten required variables
    EMSDK_PATH         ?= /home/$(USER)/emsdk
    EMSCRIPTEN_PATH    ?= $(EMSDK_PATH)/upstream/emscripten
    CLANG_PATH          = $(EMSDK_PATH)/upstream/bin
    PYTHON_PATH         = /usr/bin/python3
    NODE_PATH           = $(EMSDK_PATH)/node/14.15.5_64bit/bin
    #export PATH         = $(EMSDK_PATH);$(EMSCRIPTEN_PATH);$(CLANG_PATH);$(NODE_PATH);$(PYTHON_PATH);C:\raylib\MinGW\bin:$$(PATH)
endif

ifeq ($(PLATFORM),PLATFORM_ANDROID)
    # Android architecture
    # Starting at 2019 using arm64 is mandatory for published apps,
    # Starting on August 2020, minimum required target API is Android 10 (API level 29)
    
    ANDROID_ARCH ?= arm
    #ANDROID_ARCH ?= arm64
    #ANDROID_ARCH ?= x86_64
    #ANDROID_ARCH ?= x86
    
    ANDROID_API_VERSION ?= 29

    # Android required path variables
    # NOTE: Starting with Android NDK r21, no more toolchain generation is required, NDK is the toolchain on itself
    ifeq ($(OS),Windows_NT)
        ANDROID_NDK ?= C:/android-ndk
        ANDROID_TOOLCHAIN = $(ANDROID_NDK)/toolchains/llvm/prebuilt/windows-x86_64
    else
        ANDROID_NDK ?= /home/$(USER)/Android/Sdk/ndk/23.0.7599858
        ANDROID_TOOLCHAIN = $(ANDROID_NDK)/toolchains/llvm/prebuilt/linux-x86_64
    endif

    # NOTE: Sysroot can also be reference from $(ANDROID_NDK)/sysroot
    ANDROID_SYSROOT ?= $(ANDROID_TOOLCHAIN)/sysroot

    ifeq ($(ANDROID_ARCH),arm)
        ANDROID_ARCH_NAME = armeabi-v7a
    endif
    ifeq ($(ANDROID_ARCH),arm64)
        ANDROID_ARCH_NAME = arm64-v8a
    endif
    ifeq ($(ANDROID_ARCH),x86)
        ANDROID_ARCH_NAME = i686
    endif
    ifeq ($(ANDROID_ARCH),x86_64)
        ANDROID_ARCH_NAME = x86_64
    endif

endif

# Define raylib graphics api depending on selected platform
ifeq ($(PLATFORM),PLATFORM_DESKTOP)
    # By default use OpenGL 3.3 on desktop platforms
    GRAPHICS ?= GRAPHICS_API_OPENGL_33
    #GRAPHICS = GRAPHICS_API_OPENGL_11  # Uncomment to use OpenGL 1.1
    #GRAPHICS = GRAPHICS_API_OPENGL_21  # Uncomment to use OpenGL 2.1
endif
ifeq ($(PLATFORM),PLATFORM_RPI)
    # On RPI OpenGL ES 2.0 must be used
    GRAPHICS = GRAPHICS_API_OPENGL_ES2
endif
ifeq ($(PLATFORM),PLATFORM_DRM)
    # On DRM OpenGL ES 2.0 must be used
    GRAPHICS = GRAPHICS_API_OPENGL_ES2
endif
ifeq ($(PLATFORM),PLATFORM_WEB)
    # On HTML5 OpenGL ES 2.0 is used, emscripten translates it to WebGL 1.0
    GRAPHICS = GRAPHICS_API_OPENGL_ES2
endif
ifeq ($(PLATFORM),PLATFORM_ANDROID)
    # By default use OpenGL ES 2.0 on Android
    GRAPHICS = GRAPHICS_API_OPENGL_ES2
endif

# Define default C compiler and archiver to pack library
CC = gcc
AR = ar

ifeq ($(PLATFORM),PLATFORM_DESKTOP)
    ifeq ($(PLATFORM_OS),OSX)
        # OSX default compiler
        CC = clang
        GLFW_OSX = -x objective-c
    endif
    ifeq ($(PLATFORM_OS),BSD)
        # FreeBSD, OpenBSD, NetBSD, DragonFly default compiler
        CC = clang
    endif
endif

ifeq ($(PLATFORM),PLATFORM_RPI)
    ifeq ($(USE_RPI_CROSS_COMPILER),TRUE)
        # Define RPI cross-compiler
        #CC = armv6j-hardfloat-linux-gnueabi-gcc
        CC = $(RPI_TOOLCHAIN)/bin/arm-linux-gnueabihf-gcc
        AR = $(RPI_TOOLCHAIN)/bin/arm-linux-gnueabihf-ar
    endif
endif

ifeq ($(PLATFORM),PLATFORM_WEB)
    # HTML5 emscripten compiler
    CC = emcc
    AR = emar
endif

ifeq ($(PLATFORM),PLATFORM_ANDROID)
    # Android toolchain (must be provided for desired architecture and compiler)
    ifeq ($(ANDROID_ARCH),arm)
        CC = $(ANDROID_TOOLCHAIN)/bin/armv7a-linux-androideabi$(ANDROID_API_VERSION)-clang
        #AR = $(ANDROID_TOOLCHAIN)/bin/arm-linux-androideabi-ar
        AR = $(ANDROID_TOOLCHAIN)/bin/llvm-ar
    endif
    ifeq ($(ANDROID_ARCH),arm64)
        CC = $(ANDROID_TOOLCHAIN)/bin/aarch64-linux-android$(ANDROID_API_VERSION)-clang
        #AR = $(ANDROID_TOOLCHAIN)/bin/aarch64-linux-android-ar
        AR = $(ANDROID_TOOLCHAIN)/bin/llvm-ar
    endif
    ifeq ($(ANDROID_ARCH),x86)
        CC = $(ANDROID_TOOLCHAIN)/bin/i686-linux-android$(ANDROID_API_VERSION)-clang
        #AR = $(ANDROID_TOOLCHAIN)/bin/i686-linux-android-ar
        AR = $(ANDROID_TOOLCHAIN)/bin/llvm-ar
    endif
    ifeq ($(ANDROID_ARCH),x86_64)
        CC = $(ANDROID_TOOLCHAIN)/bin/x86_64-linux-android$(ANDROID_API_VERSION)-clang
        #AR = $(ANDROID_TOOLCHAIN)/bin/x86_64-linux-android-ar
        AR = $(ANDROID_TOOLCHAIN)/bin/llvm-ar
    endif
endif

# Define compiler flags:
#  -O1                      defines optimization level
#  -g                       include debug information on compilation
#  -s                       strip unnecessary data from build
#  -Wall                    turns on most, but not all, compiler warnings
#  -std=c99                 defines C language mode (standard C from 1999 revision)
#  -std=gnu99               defines C language mode (GNU C from 1999 revision)
#  -Wno-missing-braces      ignore invalid warning (GCC bug 53119)
#  -D_DEFAULT_SOURCE        use with -std=c99 on Linux and PLATFORM_WEB, required for timespec
#  -Werror=pointer-arith    catch unportable code that does direct arithmetic on void pointers
#  -fno-strict-aliasing     jar_xm.h does shady stuff (breaks strict aliasing)
CFLAGS += -Wall -D_DEFAULT_SOURCE -Wno-missing-braces -Werror=pointer-arith -fno-strict-aliasing

ifeq ($(PLATFORM), PLATFORM_WEB)
    CFLAGS += -std=gnu99
else
    CFLAGS += -std=c99
endif

ifeq ($(PLATFORM_OS), LINUX)
    CFLAGS += -fPIC
endif

ifeq ($(RAYLIB_BUILD_MODE),DEBUG)
    CFLAGS += -g
endif

ifeq ($(RAYLIB_BUILD_MODE),RELEASE)
    ifeq ($(PLATFORM),PLATFORM_WEB)
        CFLAGS += -Os
    endif
    ifeq ($(PLATFORM),PLATFORM_DESKTOP)
        CFLAGS += -s -O1
    endif
    ifeq ($(PLATFORM),PLATFORM_ANDROID)
        CFLAGS += -O2
    endif
endif

# Additional flags for compiler (if desired)
#  -Wextra                  enables some extra warning flags that are not enabled by -Wall
#  -Wmissing-prototypes     warn if a global function is defined without a previous prototype declaration
#  -Wstrict-prototypes      warn if a function is declared or defined without specifying the argument types
#  -Werror=implicit-function-declaration   catch function calls without prior declaration
ifeq ($(PLATFORM),PLATFORM_DESKTOP)
    CFLAGS += -Werror=implicit-function-declaration
endif
ifeq ($(PLATFORM),PLATFORM_WEB)
    # -Os                        # size optimization
    # -O2                        # optimization level 2, if used, also set --memory-init-file 0
    # -s USE_GLFW=3              # Use glfw3 library (context/input management)
    # -s ALLOW_MEMORY_GROWTH=1   # to allow memory resizing -> WARNING: Audio buffers could FAIL!
    # -s TOTAL_MEMORY=16777216   # to specify heap memory size (default = 16MB)
    # -s USE_PTHREADS=1          # multithreading support
    # -s FORCE_FILESYSTEM=1      # force filesystem to load/save files data
    # -s ASSERTIONS=1            # enable runtime checks for common memory allocation errors (-O1 and above turn it off)
    # --profiling                # include information for code profiling
    # --memory-init-file 0       # to avoid an external memory initialization code file (.mem)
    # --preload-file resources   # specify a resources folder for data compilation
    CFLAGS += -s USE_GLFW=3
    ifeq ($(RAYLIB_BUILD_MODE),DEBUG)
        CFLAGS += -s ASSERTIONS=1 --profiling
    endif
endif
ifeq ($(PLATFORM),PLATFORM_ANDROID)
    # Compiler flags for arquitecture
    ifeq ($(ANDROID_ARCH),arm)
        CFLAGS += -march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3-d16
    endif
    ifeq ($(ANDROID_ARCH),arm64)
        #CFLAGS += -target aarch64 -mfix-cortex-a53-835769
        CFLAGS += -m64
        
        
    endif
    ifeq ($(ANDROID_ARCH), x86)
        CFLAGS += -march=i686
    endif
    ifeq ($(ANDROID_ARCH), x86_64)
        CFLAGS += -march=x86-64
    endif
    # Compilation functions attributes options
    CFLAGS += -ffunction-sections -funwind-tables -fstack-protector-strong -fPIE -fPIC
    # Compiler options for the linker
    # -Werror=format-security
    CFLAGS += -Wa,--noexecstack -Wformat -no-canonical-prefixes
    # Preprocessor macro definitions
    CFLAGS += -DANDROID -DPLATFORM_ANDROID -D__ANDROID_API__=$(ANDROID_API_VERSION) -DMAL_NO_OSS
endif

# Define required compilation flags for raylib SHARED lib
ifeq ($(RAYLIB_LIBTYPE),SHARED)
    # make sure code is compiled as position independent
    # BE CAREFUL: It seems that for gcc -fpic is not the same as -fPIC
    # MinGW32 just doesn't need -fPIC, it shows warnings
    CFLAGS += -fPIC -DBUILD_LIBTYPE_SHARED
endif
ifeq ($(PLATFORM),PLATFORM_DRM)
    # without EGL_NO_X11 eglplatform.h tears Xlib.h in which tears X.h in
    # which contains a conflicting type Font
    CFLAGS += -DEGL_NO_X11
endif

# Use Wayland display on Linux desktop
ifeq ($(PLATFORM),PLATFORM_DESKTOP)
    ifeq ($(PLATFORM_OS), LINUX)
        ifeq ($(USE_WAYLAND_DISPLAY),TRUE)
            CFLAGS += -D_GLFW_WAYLAND
        else
            LDLIBS = -lX11
        endif
    endif
endif

# Define include paths for required headers
# NOTE: Several external required libraries (stb and others)
INCLUDE_PATHS = -I. -Iexternal/glfw/include -Iexternal/glfw/deps/mingw

ifeq ($(PLATFORM),PLATFORM_DESKTOP)
    ifeq ($(PLATFORM_OS),BSD)
        INCLUDE_PATHS += -I/usr/local/include
        LDFLAGS += -L. -Lsrc -L/usr/local/lib -L$(RAYLIB_RELEASE_PATH)
    endif
    ifeq ($(USE_EXTERNAL_GLFW),TRUE)
        # Check the version name. If GLFW3 was built manually, it may have produced
        # a static library known as libglfw3.a. In that case, the name should be -lglfw3
        LDFLAGS += -lglfw
    endif
endif

# Define additional directories containing required header files
ifeq ($(PLATFORM),PLATFORM_RPI)
    # RPI required libraries
    INCLUDE_PATHS += -I$(RPI_TOOLCHAIN_SYSROOT)/opt/vc/include
    INCLUDE_PATHS += -I$(RPI_TOOLCHAIN_SYSROOT)/opt/vc/include/interface/vmcs_host/linux
    INCLUDE_PATHS += -I$(RPI_TOOLCHAIN_SYSROOT)/opt/vc/include/interface/vcos/pthreads
endif
ifeq ($(PLATFORM),PLATFORM_DRM)
    # DRM required libraries
    INCLUDE_PATHS += -I/usr/include/libdrm
endif
ifeq ($(PLATFORM),PLATFORM_ANDROID)
    NATIVE_APP_GLUE = $(ANDROID_NDK)/sources/android/native_app_glue
    # Include android_native_app_glue.h
    INCLUDE_PATHS += -I$(NATIVE_APP_GLUE)

    # Android required libraries
    INCLUDE_PATHS += -I$(ANDROID_SYSROOT)/usr/include
    ifeq ($(ANDROID_ARCH),arm)
        INCLUDE_PATHS += -I$(ANDROID_SYSROOT)/usr/include/arm-linux-androideabi
    endif
    ifeq ($(ANDROID_ARCH),arm64)
        INCLUDE_PATHS += -I$(ANDROID_SYSROOT)/usr/include/aarch64-linux-android
    endif
    ifeq ($(ANDROID_ARCH),x86)
        INCLUDE_PATHS += -I$(ANDROID_SYSROOT)/usr/include/i686-linux-android
    endif
    ifeq ($(ANDROID_ARCH),x86_64)
        INCLUDE_PATHS += -I$(ANDROID_SYSROOT)/usr/include/x86_64-linux-android
    endif
endif

# Define linker options
ifeq ($(PLATFORM),PLATFORM_ANDROID)
    LDFLAGS += -Wl,-soname,libraylib.$(API_VERSION).so -Wl,--exclude-libs,libatomic.a
    LDFLAGS += -Wl,--build-id -Wl,-z,noexecstack -Wl,-z,relro -Wl,-z,now -Wl,--warn-shared-textrel -Wl,--fatal-warnings
    # Force linking of library module to define symbol
    LDFLAGS += -u ANativeActivity_onCreate
    # Library paths containing required libs
    LDFLAGS += -L. -Lsrc -L$(RAYLIB_RELEASE_PATH)
    # Avoid unresolved symbol pointing to external main()
    LDFLAGS += -Wl,-undefined,dynamic_lookup

    LDLIBS += -llog -landroid -lEGL -lGLESv2 -lOpenSLES -lc -lm
endif

# Define all object files required with a wildcard
# The wildcard takes all files that finish with ".c",
# and replaces extentions with ".o", that are the object files
# NOTE: Some objects depend on the PLATFORM to be added or not!
# OBJS = $(patsubst %.c, %.o, $(wildcard *.c))

# Define object required on compilation
OBJS = core.o \
       shapes.o \
       textures.o \
       text.o \
       utils.o

ifeq ($(PLATFORM),PLATFORM_DESKTOP)
    ifeq ($(USE_EXTERNAL_GLFW),FALSE)
        OBJS += rglfw.o
    endif
endif
ifeq ($(RAYLIB_MODULE_MODELS),TRUE)
    OBJS += models.o
endif
ifeq ($(RAYLIB_MODULE_AUDIO),TRUE)
    OBJS += raudio.o
endif
ifeq ($(RAYLIB_MODULE_RAYGUI),TRUE)
    OBJS += raygui.o
endif
ifeq ($(RAYLIB_MODULE_PHYSAC),TRUE)
    OBJS += physac.o
endif

#ifeq ($(RAYLIB_MODULE_NET),TRUE)
#    OBJS += rnet.o
#endif
ifeq ($(RAYLIB_MODULE_PNG),TRUE)
    OBJS += rpng.o
endif

ifeq ($(PLATFORM),PLATFORM_ANDROID)
    OBJS += android_native_app_glue.o
endif

# Default target entry
all: raylib

# Compile raylib library
# NOTE: Release directory is created if not exist
raylib: $(OBJS)
ifeq ($(PLATFORM),PLATFORM_WEB)
    # Compile raylib libray for web
    #$(CC) $(OBJS) -r -o $(RAYLIB_RELEASE_PATH)/lib$(RAYLIB_LIB_NAME).bc
	$(AR) rcs $(RAYLIB_RELEASE_PATH)/lib$(RAYLIB_LIB_NAME).a $(OBJS)
	@echo "raylib library generated (lib$(RAYLIB_LIB_NAME).a)!"
else
    ifeq ($(RAYLIB_LIBTYPE),SHARED)
        ifeq ($(PLATFORM),PLATFORM_DESKTOP)
            ifeq ($(PLATFORM_OS),WINDOWS)
                # NOTE: Linking with provided resource file
				$(CC) -shared -o $(RAYLIB_RELEASE_PATH)/$(RAYLIB_LIB_NAME).dll $(OBJS) $(RAYLIB_RES_FILE) $(LDFLAGS) -static-libgcc -lopengl32 -lgdi32 -lwinmm -Wl,--out-implib,$(RAYLIB_RELEASE_PATH)/lib$(RAYLIB_LIB_NAME)dll.a
				@echo "raylib dynamic library ($(RAYLIB_LIB_NAME).dll) and import library (lib$(RAYLIB_LIB_NAME)dll.a) generated!"
            endif
            ifeq ($(PLATFORM_OS),LINUX)
                # Compile raylib shared library version $(RAYLIB_VERSION).
                # WARNING: you should type "make clean" before doing this target
				$(CC) -shared -o $(RAYLIB_RELEASE_PATH)/lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_VERSION) $(OBJS) $(LDFLAGS) -Wl,-soname,lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_API_VERSION) -lGL -lc -lm -lpthread -ldl -lrt $(LDLIBS)
				@echo "raylib shared library generated (lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_VERSION)) in $(RAYLIB_RELEASE_PATH)!"
				cd $(RAYLIB_RELEASE_PATH) && ln -fsv lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_VERSION) lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_API_VERSION)
				cd $(RAYLIB_RELEASE_PATH) && ln -fsv lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_API_VERSION) lib$(RAYLIB_LIB_NAME).so
            endif
            ifeq ($(PLATFORM_OS),OSX)
				$(CC) -dynamiclib -o $(RAYLIB_RELEASE_PATH)/lib$(RAYLIB_LIB_NAME).$(RAYLIB_VERSION).dylib $(OBJS) $(LDFLAGS) -compatibility_version $(RAYLIB_API_VERSION) -current_version $(RAYLIB_VERSION) -framework OpenGL -framework Cocoa -framework IOKit -framework CoreAudio -framework CoreVideo
				install_name_tool -id "lib$(RAYLIB_LIB_NAME).$(VERSION).dylib" $(RAYLIB_RELEASE_PATH)/lib$(RAYLIB_LIB_NAME).$(RAYLIB_VERSION).dylib
				@echo "raylib shared library generated (lib$(RAYLIB_LIB_NAME).$(RAYLIB_VERSION).dylib)!"
				cd $(RAYLIB_RELEASE_PATH) && ln -fs lib$(RAYLIB_LIB_NAME).$(RAYLIB_VERSION).dylib lib$(RAYLIB_LIB_NAME).$(RAYLIB_API_VERSION).dylib
				cd $(RAYLIB_RELEASE_PATH) && ln -fs lib$(RAYLIB_LIB_NAME).$(RAYLIB_VERSION).dylib lib$(RAYLIB_LIB_NAME).dylib
            endif
            ifeq ($(PLATFORM_OS),BSD)
                # WARNING: you should type "gmake clean" before doing this target
				$(CC) -shared -o $(RAYLIB_RELEASE_PATH)/lib$(RAYLIB_LIB_NAME).$(RAYLIB_VERSION).so $(OBJS) $(LDFLAGS) -Wl,-soname,lib$(RAYLIB_LIB_NAME).$(RAYLIB_API_VERSION).so -lGL -lpthread
				@echo "raylib shared library generated (lib$(RAYLIB_LIB_NAME).$(RAYLIB_VERSION).so)!"
				cd $(RAYLIB_RELEASE_PATH) && ln -fs lib$(RAYLIB_LIB_NAME).$(RAYLIB_VERSION).so lib$(RAYLIB_LIB_NAME).$(RAYLIB_API_VERSION).so
				cd $(RAYLIB_RELEASE_PATH) && ln -fs lib$(RAYLIB_LIB_NAME).$(RAYLIB_VERSION).so lib$(RAYLIB_LIB_NAME).so
            endif
        endif
        ifeq ($(PLATFORM),PLATFORM_RPI)
                # Compile raylib shared library version $(RAYLIB_VERSION).
                # WARNING: you should type "make clean" before doing this target
				$(CC) -shared -o $(RAYLIB_RELEASE_PATH)/lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_VERSION) $(OBJS) $(LDFLAGS) -Wl,-soname,lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_API_VERSION) -L/opt/vc/lib -lbrcmGLESv2 -lbrcmEGL -lpthread -lrt -lm -lbcm_host -ldl
				@echo "raylib shared library generated (lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_VERSION)) in $(RAYLIB_RELEASE_PATH)!"
				cd $(RAYLIB_RELEASE_PATH) && ln -fsv lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_VERSION) lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_API_VERSION)
				cd $(RAYLIB_RELEASE_PATH) && ln -fsv lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_API_VERSION) lib$(RAYLIB_LIB_NAME).so
        endif
        ifeq ($(PLATFORM),PLATFORM_DRM)
                # Compile raylib shared library version $(RAYLIB_VERSION).
                # WARNING: you should type "make clean" before doing this target
				$(CC) -shared -o $(RAYLIB_RELEASE_PATH)/lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_VERSION) $(OBJS) $(LDFLAGS) -Wl,-soname,lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_API_VERSION) -lGLESv2 -lEGL -ldrm -lgbm -lpthread -lrt -lm -ldl
				@echo "raylib shared library generated (lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_VERSION)) in $(RAYLIB_RELEASE_PATH)!"
				cd $(RAYLIB_RELEASE_PATH) && ln -fsv lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_VERSION) lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_API_VERSION)
				cd $(RAYLIB_RELEASE_PATH) && ln -fsv lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_API_VERSION) lib$(RAYLIB_LIB_NAME).so
        endif
        ifeq ($(PLATFORM),PLATFORM_ANDROID)
			$(CC) -shared -o $(RAYLIB_RELEASE_PATH)/lib$(RAYLIB_LIB_NAME).$(RAYLIB_VERSION).so $(OBJS) $(LDFLAGS) $(LDLIBS)
			@echo "raylib shared library generated (lib$(RAYLIB_LIB_NAME).$(RAYLIB_VERSION).so)!"
            # WARNING: symbolic links creation on Windows should be done using mklink command, no ln available
            ifeq ($(HOST_PLATFORM_OS),LINUX)
				cd $(RAYLIB_RELEASE_PATH) && ln -fs lib$(RAYLIB_LIB_NAME).$(RAYLIB_VERSION).so lib$(RAYLIB_LIB_NAME).$(RAYLIB_API_VERSION).so
				cd $(RAYLIB_RELEASE_PATH) && ln -fs lib$(RAYLIB_LIB_NAME).$(RAYLIB_VERSION).so lib$(RAYLIB_LIB_NAME).so
            endif
        endif
    else
        # Compile raylib static library version $(RAYLIB_VERSION)
        # WARNING: You should type "make clean" before doing this target.
		$(AR) rcs $(RAYLIB_RELEASE_PATH)/lib$(RAYLIB_LIB_NAME).a $(OBJS)
		@echo "raylib static library generated (lib$(RAYLIB_LIB_NAME).a) in $(RAYLIB_RELEASE_PATH)!"
    endif
endif

# Compile all modules with their prerequisites

# Compile core module
core.o : core.c raylib.h rlgl.h utils.h raymath.h camera.h gestures.h
	$(CC) -c $< $(CFLAGS) $(INCLUDE_PATHS) -D$(PLATFORM) -D$(GRAPHICS)

# Compile rglfw module
rglfw.o : rglfw.c
	$(CC) $(GLFW_OSX) -c $< $(CFLAGS) $(INCLUDE_PATHS) -D$(PLATFORM) -D$(GRAPHICS)

# Compile shapes module
shapes.o : shapes.c raylib.h rlgl.h
	$(CC) -c $< $(CFLAGS) $(INCLUDE_PATHS) -D$(PLATFORM) -D$(GRAPHICS)

# Compile textures module
textures.o : textures.c raylib.h rlgl.h utils.h
	$(CC) -c $< $(CFLAGS) $(INCLUDE_PATHS) -D$(PLATFORM) -D$(GRAPHICS)

# Compile text module
text.o : text.c raylib.h utils.h
	$(CC) -c $< $(CFLAGS) $(INCLUDE_PATHS) -D$(PLATFORM) -D$(GRAPHICS)

# Compile utils module
utils.o : utils.c utils.h
	$(CC) -c $< $(CFLAGS) $(INCLUDE_PATHS) -D$(PLATFORM)

# Compile models module
models.o : models.c raylib.h rlgl.h raymath.h
	$(CC) -c $< $(CFLAGS) $(INCLUDE_PATHS) -D$(PLATFORM) -D$(GRAPHICS)

# Compile audio module
raudio.o : raudio.c raylib.h
	$(CC) -c $< $(CFLAGS) $(INCLUDE_PATHS) -D$(PLATFORM)

# Compile raygui module
# NOTE: raygui header should be distributed with raylib.h
raygui.o : raygui.c raygui.h gui_textbox_extended.h ricons.h
	$(CC) -c $< $(CFLAGS) $(INCLUDE_PATHS) -D$(PLATFORM) -DRAYGUI_IMPLEMENTATION
raygui.c:
	echo '#define RAYGUI_IMPLEMENTATION' > raygui.c
	echo '#include "$(RAYLIB_MODULE_RAYGUI_PATH)/raygui.h"' >> raygui.c

# Compile physac module
# NOTE: physac header should be distributed with raylib.h
physac.o : physac.c physac.h
	$(CC) -c $< $(CFLAGS) $(INCLUDE_PATHS) -D$(PLATFORM) -DPHYSAC_IMPLEMENTATION
physac.c:	
	@echo '#define PHYSAC_IMPLEMENTATION' > physac.c
	@echo '#include "$(RAYLIB_MODULE_PHYSAC_PATH)/physac.h"' > physac.c

# Compile rpng module
rpng.o : rpng.c rpng.h
	$(CC) -c $< $(CFLAGS) $(INCLUDE_PATHS) -D$(PLATFORM) -DRNET_IMPLEMENTATION
rpng.c:	
	@echo '#define RNET_IMPLEMENTATION' > rpng.c
	@echo '#include "$(RAYLIB_MODULE_PNG_PATH)/rpng.h"' > rpng.c

# Compile rnet module
#rnet.o : rnet.c rnet.h
#	$(CC) -c $< $(CFLAGS) $(INCLUDE_PATHS) -D$(PLATFORM) -DRNET_IMPLEMENTATION
#rnet.c:	
#	@echo '#define RNET_IMPLEMENTATION' > rnet.c
#	@echo '#include "$(RAYLIB_MODULE_NET_PATH)/rnet.h"' > rnet.c

# Compile android_native_app_glue module
android_native_app_glue.o : $(NATIVE_APP_GLUE)/android_native_app_glue.c
	$(CC) -c $< $(CFLAGS) $(INCLUDE_PATHS)


# Install generated and needed files to desired directories.
# On GNU/Linux and BSDs, there are some standard directories that contain extra
# libraries and header files. These directories (often /usr/local/lib and
# /usr/local/include) are for libraries that are installed manually
# (without a package manager). We'll use /usr/local/lib/raysan5 and /usr/local/include/raysan5
# for our -L and -I specification to simplify management of the raylib source package.
# Customize these locations if you like but don't forget to pass them to make
# for compilation and enable runtime linking with -rpath, LD_LIBRARY_PATH, or ldconfig.
# Hint: add -L$(RAYLIB_INSTALL_PATH) -I$(RAYLIB_H_INSTALL_PATH) to your own makefiles.
# See below and ../examples/Makefile for more information.
# TODO: Add other platforms. Remove sudo requirement, i.e. add USER mode.

# RAYLIB_INSTALL_PATH should be the desired full path to libraylib. No relative paths.
DESTDIR ?= /usr/local
RAYLIB_INSTALL_PATH ?= $(DESTDIR)/lib
# RAYLIB_H_INSTALL_PATH locates the installed raylib header and associated source files.
RAYLIB_H_INSTALL_PATH ?= $(DESTDIR)/include

install :
ifeq ($(ROOT),root)
    ifeq ($(PLATFORM_OS),LINUX)
        # Attention! You are root, writing files to $(RAYLIB_INSTALL_PATH)
        # and $(RAYLIB_H_INSTALL_PATH). Consult this Makefile for more information.
        # Prepare the environment as needed.
		mkdir --parents --verbose $(RAYLIB_INSTALL_PATH)
		mkdir --parents --verbose $(RAYLIB_H_INSTALL_PATH)
        ifeq ($(RAYLIB_LIBTYPE),SHARED)
            # Installing raylib to $(RAYLIB_INSTALL_PATH).
			cp --update --verbose $(RAYLIB_RELEASE_PATH)/libraylib.so.$(RAYLIB_VERSION) $(RAYLIB_INSTALL_PATH)/lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_VERSION)
			cd $(RAYLIB_INSTALL_PATH); ln -fsv lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_VERSION) lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_API_VERSION)
			cd $(RAYLIB_INSTALL_PATH); ln -fsv lib$(RAYLIB_LIB_NAME).so.$(RAYLIB_API_VERSION) lib$(RAYLIB_LIB_NAME).so
            # Uncomment to update the runtime linker cache with RAYLIB_INSTALL_PATH.
            # Not necessary if later embedding RPATH in your executable. See examples/Makefile.
			ldconfig $(RAYLIB_INSTALL_PATH)
        else
            # Installing raylib to $(RAYLIB_INSTALL_PATH).
			cp --update --verbose $(RAYLIB_RELEASE_PATH)/lib$(RAYLIB_LIB_NAME).a $(RAYLIB_INSTALL_PATH)/lib$(RAYLIB_LIB_NAME).a
        endif
        # Copying raylib development files to $(RAYLIB_H_INSTALL_PATH).
		cp --update raylib.h $(RAYLIB_H_INSTALL_PATH)/raylib.h
		cp --update raymath.h $(RAYLIB_H_INSTALL_PATH)/raymath.h
		cp --update rlgl.h $(RAYLIB_H_INSTALL_PATH)/rlgl.h
		cp --update extras/physac.h $(RAYLIB_H_INSTALL_PATH)/physac.h
		@echo "raylib development files installed/updated!"
    else
		@echo "This function currently works on GNU/Linux systems. Add yours today (^;"
    endif
else
	@echo "Error: Root permissions needed for installation. Try sudo make install"
endif

# Remove raylib dev files installed on the system
# TODO: see 'install' target.
uninstall :
ifeq ($(ROOT),root)
    # WARNING: You are root, about to delete items from $(RAYLIB_INSTALL_PATH).
    # and $(RAYLIB_H_INSTALL_PATH). Please confirm each item.
    ifeq ($(PLATFORM_OS),LINUX)
        ifeq ($(RAYLIB_LIBTYPE),SHARED)
		rm --force --interactive --verbose $(RAYLIB_INSTALL_PATH)/libraylib.so
		rm --force --interactive --verbose $(RAYLIB_INSTALL_PATH)/libraylib.so.$(RAYLIB_API_VERSION)
		rm --force --interactive --verbose $(RAYLIB_INSTALL_PATH)/libraylib.so.$(RAYLIB_VERSION)
        # Uncomment to clean up the runtime linker cache. See install target.
		ldconfig
        else
		rm --force --interactive --verbose $(RAYLIB_INSTALL_PATH)/libraylib.a
        endif
		rm --force --interactive --verbose $(RAYLIB_H_INSTALL_PATH)/raylib.h
		rm --force --interactive --verbose $(RAYLIB_H_INSTALL_PATH)/raymath.h
		rm --force --interactive --verbose $(RAYLIB_H_INSTALL_PATH)/rlgl.h
		rm --force --interactive --verbose $(RAYLIB_H_INSTALL_PATH)/physac.h
		@echo "raylib development files removed!"
        else
		@echo "This function currently works on GNU/Linux systems. Add yours today (^;"
    endif
else
	@echo "Error: Root permissions needed for uninstallation. Try sudo make uninstall"
endif

# Clean everything
clean:
ifeq ($(PLATFORM_OS),WINDOWS)
	del *.o /s
	cd $(RAYLIB_RELEASE_PATH)
	del lib$(RAYLIB_LIB_NAME).a /s
	del lib$(RAYLIB_LIB_NAME)dll.a /s
	del $(RAYLIB_LIB_NAME).dll /s
else
	rm -fv *.o $(RAYLIB_RELEASE_PATH)/lib$(RAYLIB_LIB_NAME).a $(RAYLIB_RELEASE_PATH)/lib$(RAYLIB_LIB_NAME).bc $(RAYLIB_RELEASE_PATH)/lib$(RAYLIB_LIB_NAME).so*
endif
ifeq ($(PLATFORM),PLATFORM_ANDROID)
	# rm -rf $(ANDROID_TOOLCHAIN) $(NATIVE_APP_GLUE)/android_native_app_glue.o
endif
	@echo ""
	@echo "removed all generated files! (-😁.😁.😁-)"
