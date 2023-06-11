#!/bin/bash
./.starbound/linux/asset_packer ./src ./publish/contents.pak
cp -f ./publish/contents.pak ./.starbound/mods/autocrafters.pak


wdir=$(pwd)
cp -f ./web/publish.vdf ./web/_publish.vdf
sed -i "s|\${workspace}|$wdir|" ./web/_publish.vdf