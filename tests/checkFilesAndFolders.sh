#!/bin/bash
# Copyright 2018 Tobias Weber weber@lrz.de
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
