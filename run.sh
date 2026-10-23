./compile_shaders.sh
FOLDER=./examples/platformer
# odin run ./examples/camera/camera.odin.odin -file -out:./examples/platformer/platformer -keep-executable -debug
odin run $FOLDER/platformer.odin -file -debug
# odin build $FOLDER/platformer.odin -file -debug -out:$FOLDER/platformer
# raddbg $FOLDER/platformer
