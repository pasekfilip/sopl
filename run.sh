./compile_shaders.sh
FOLDER=./examples/netcode_pong
NAME=$(basename $FOLDER)
# odin run $FOLDER -debug -keep-executable -out:$FOLDER/$NAME
odin build $FOLDER -debug -out:$FOLDER/$NAME
# $FOLDER/$NAME client
# $FOLDER/$NAME no

# raddbg $FOLDER/$NAME
