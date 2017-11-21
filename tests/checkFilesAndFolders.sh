echo "Checking important files and folders!"
for file in k8s-node.yml k8s-master.yml README.md .editorconfig
do
    if [ ! -f "$file" ]
    then
        echo "FAILURE: $file is missing"
        exit 1
    fi
done

for dir in roles
do
    if [ ! -d "$dir" ]
    then
        echo "FAILURE $dir is missing"
        exit 1
    fi
done

echo "All important files and folders are at their place :)"
