#!/bin/bash
echo "check for unvalid yml"
find -name "*.yml" -exec python -c "from yaml import load, Loader; load(open('{}'), Loader=Loader)" \;
