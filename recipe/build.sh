#!/bin/bash

# We let PREFIX being expanded everywhere in the script.
# conda will automatically replace it during installation.
# Note that this isn't true for BUILD_PREFIX.
EPICS_BASE="$PREFIX/epics"
EPICS_HOST_ARCH=$(perl src/tools/EpicsHostArch.pl)

cat << EOF >> configure/CONFIG_SITE.local
INSTALL_LOCATION=${EPICS_BASE}
MSI=\$(EPICS_BASE)/bin/\$(EPICS_HOST_ARCH)/msi
EOF

if [[ "$host_alias" != "$build_alias" ]]
then
  echo "CROSS_COMPILER_TARGET_ARCHS=darwin-aarch64" >> configure/CONFIG_SITE

  # To cross-compile for Apple M1, we first have to compile for x86
  # The readline found is the host one (arm64)
  # We don't need it here as x86 is only used for compilation
  # -> we force COMMANDLINE_LIBRARY to EPICS (instead of readline)
  cat << EOF >> configure/os/CONFIG_SITE.Common.darwin-x86
CC = ${CC_FOR_BUILD}
CCC = ${CXX_FOR_BUILD}
AR = ${build_alias}-ar -rc
RANLIB = ${build_alias}-ranlib
COMMANDLINE_LIBRARY=EPICS
OP_SYS_LDFLAGS = -Wl,-rpath,\${BUILD_PREFIX}/lib -L\${BUILD_PREFIX}/lib
OP_SYS_INCLUDES = -I\${BUILD_PREFIX}/include
EOF
fi

cat << EOF >> configure/os/CONFIG_SITE.Common.linuxCommon
# GCC15 defaults to gnu23 but EPICS ecosystem needs gnu17
POSIX_CFLAGS += -std=gnu17
# Set GNU_DIR to BUILD_PREFIX or PREFIX if not set (when not using conda-build)
# Allow to compile without conda-build by installing manually the compilers
# in a local conda environment
GNU_DIR = \$(or \$(BUILD_PREFIX),$PREFIX)
CMPLR_PREFIX=\$(patsubst %-gcc,%-,\$(notdir ${GCC}))

# --disable-new-dtags is required to avoid LD_LIBRARY_PATH overrride RPATH settings
OP_SYS_LDFLAGS += -Wl,--disable-new-dtags -Wl,-rpath,${PREFIX}/lib -Wl,-rpath-link,${PREFIX}/lib -L${PREFIX}/lib -Wl,-rpath-link,${EPICS_BASE}/lib/${EPICS_HOST_ARCH}
OP_SYS_INCLUDES += -I${PREFIX}/include
EOF

cat << EOF >> configure/os/CONFIG_SITE.darwinCommon.darwinCommon
CC = ${CC}
CCC = ${CXX}
AR = ${AR} -rc
RANLIB = ${RANLIB}

# GCC15 defaults to gnu23 but EPICS ecosystem needs gnu17
POSIX_CFLAGS += -std=gnu17
OP_SYS_CFLAGS += -isysroot \${CONDA_BUILD_SYSROOT} -mmacosx-version-min=\${MACOSX_DEPLOYMENT_TARGET}
OP_SYS_CXXFLAGS += -isysroot \${CONDA_BUILD_SYSROOT} -mmacosx-version-min=\${MACOSX_DEPLOYMENT_TARGET}
OP_SYS_LDFLAGS += -Wl,-rpath,${PREFIX}/lib -L${PREFIX}/lib
OP_SYS_INCLUDES += -I${PREFIX}/include
EOF

# Compile epics-base
make -j${CPU_COUNT}

# run epics-base tests
[[ ${PKG_NAME} != "epics-base-static-libs" && "$target_platform" == linux-* ]] &&  make -j${CPU_COUNT} runtests

# Create files to set/unset variables when running
# activate/deactivate

# Note that modifying the PATH in deactivate scripts require conda >= 4.7
mkdir -p $PREFIX/etc/conda/activate.d
cat <<EOF > $PREFIX/etc/conda/activate.d/epics-base_activate.sh
export EPICS_BASE="$EPICS_BASE"
EOF
if [[ "$host_alias" != "$build_alias" ]]
then
  # When cross-compiling for Apple M1, the perl installed in the host environment will fail to run on the build host.
  # This is why we fallback to ${BUILD_PREFIX}/bin/perl to set EPICS_HOST_ARCH
  # EPICS_HOST_ARCH should be set to the build host arch, this is why it's done at activation time.
  cat <<EOF >> $PREFIX/etc/conda/activate.d/epics-base_activate.sh
export EPICS_HOST_ARCH="\$(perl ${EPICS_BASE}/lib/perl/EpicsHostArch.pl 2> /dev/null || \${BUILD_PREFIX}/bin/perl ${EPICS_BASE}/lib/perl/EpicsHostArch.pl)"
EOF
else
  cat <<EOF >> $PREFIX/etc/conda/activate.d/epics-base_activate.sh
export EPICS_HOST_ARCH="$EPICS_HOST_ARCH"
EOF
fi
cat <<EOF >> $PREFIX/etc/conda/activate.d/epics-base_activate.sh
export EPICS_BASE_HOST_BIN="${EPICS_BASE}/bin/\${EPICS_HOST_ARCH}"
export EPICS_BASE_VERSION="${PKG_VERSION}"
export PATH=\$EPICS_BASE_HOST_BIN:\$PATH
EOF

mkdir -p $PREFIX/etc/conda/deactivate.d
cat <<EOF > $PREFIX/etc/conda/deactivate.d/epics-base_deactivate.sh
unset EPICS_BASE
unset EPICS_HOST_ARCH
unset EPICS_BASE_VERSION
export PATH=\$(echo \$PATH | sed "s?\$EPICS_BASE_HOST_BIN:??")
unset EPICS_BASE_HOST_BIN
EOF
