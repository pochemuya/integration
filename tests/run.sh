#!/bin/bash
set -x -e

if [[ ! -f large_image.dat ]]; then
    dd if=/dev/zero of=large_image.dat bs=200M count=0 seek=1
fi

if [[ -n "$BUILDDIR" ]]; then
    # Get the necessary path directly from the build.

    # On branches without recipe specific sysroots, the next step will fail
    # because the prepare_recipe_sysroot task doesn't exist. Use that failure
    # to fall back to the old generic sysroot path.
    if ( cd $BUILDDIR && bitbake -c prepare_recipe_sysroot mender-test-dependencies ); then
        eval `cd $BUILDDIR && bitbake -e mender-test-dependencies | grep '^export PATH='`
    else
        eval `cd $BUILDDIR && bitbake -e core-image-minimal | grep '^export PATH='`
    fi

    cp -f $BUILDDIR/tmp/deploy/images/vexpress-qemu/core-image-full-cmdline-vexpress-qemu.ext4 .
else
    # Download what we need.

    mkdir -p downloaded-tools
    if [[ ! -f downloaded-tools/mender-artifact ]]; then
        curl "https://d25phv8h0wbwru.cloudfront.net/master/tip/mender-artifact" -o downloaded-tools/mender-artifact
    fi
    chmod +x downloaded-tools/mender-artifact
    export PATH=$PWD/downloaded-tools:$PATH

    if [[ ! -f core-image-full-cmdline-vexpress-qemu.ext4 ]] ; then
        echo "!! WARNING: core-image-file-cmdline-vexpress-qemu.ext4 was not found, will download the latest !!"
        curl -o core-image-full-cmdline-vexpress-qemu.ext4 "https://s3.amazonaws.com/mender/temp/core-image-full-cmdline-vexpress-qemu.ext4"
    fi
fi

cp -f core-image-full-cmdline-vexpress-qemu.ext4 core-image-full-cmdline-vexpress-qemu-broken-network.ext4
e2rm core-image-full-cmdline-vexpress-qemu-broken-network.ext4:/lib/systemd/systemd-networkd

dd if=/dev/urandom of=broken_update.ext4 bs=10M count=5

if [ $# -eq 0 ]; then
    py.test --maxfail=1 -s --tb=short --verbose --junitxml=results.xml --runfast --runslow
    exit $?
fi

py.test --maxfail=1 -s --tb=short --verbose --junitxml=results.xml "$@"
