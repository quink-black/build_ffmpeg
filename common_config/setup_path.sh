if [ -z "$project_root" ]; then
    echo 'must set $project_root first'
    exit 1
fi

if [ -z "$platform" ]; then
    echo 'must set $platform first'
    exit 1
fi

third_party_dir="$project_root/third_party"
install_dir="$third_party_dir/install_$platform"
build_dir="$third_party_dir/build/$platform"
