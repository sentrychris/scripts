#!/usr/bin/env bash

keyGen() {
    echo "Generating keys..."
    i=1
    for ro in {1..15}
    do
        openssl rand -hex 16 | while read line;
                               do
                                   echo "$i;$line" >> keys
                               done
        (( i++ ))
    done

    if [[ -s keys ]]
    then
        echo "Keys successfullly generated!"
        echo "Encrypting key file..."
        openssl enc -aes-256-cbc -k  -in keys -out keys.enc
        if [[ -s keys.enc ]]
        then
            echo "Key file successfully encrypted!"
        else
            echo "Error. Could not encrypt key file."
        fi
    else
        echo "Error. Could not generate keyfile, please check your syntax."
    fi
}

keyGen
