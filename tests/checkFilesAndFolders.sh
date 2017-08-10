echo "Checking important files and folders!"
for file in kubernetes-nodes.yml kubernetes-master.yml
do
    if [ ! -f "$file" ]
    then
        echo "FAILURE: $file is missing"
        exit 1
    fi
done

for dir in roles group_vars
do
    if [ ! -d "$dir" ]
    then
        echo "FAILURE $dir is missing"
        exit 1
    fi
done

echo "All important files and folders are at their place :)"
