#!/bin/bash

rm functions/*.zip 
current_dir=$(pwd)
zipThis(){
    cd $current_dir/functions/$1
    zip -r ../$1.zip *
}

zipThis proxy
zipThis shutdown
zipThis clean_up

