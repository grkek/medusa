build:
	mkdir -p ./bin
	cc -std=c++20 -c ./src/ext/*.cpp -I${LIBGC}/include/ -o ./bin/medusa.o
	ar rcs ./bin/medusa.a ./bin/*.o

quickjs:
	cd ./src/ext/quickjs && make all

test:
	make quickjs
	make build
	crystal run example/hello_world.cr -Dpreview_mt

clean:
	rm -rf ./bin/**
	cd ./src/ext/quickjs && make clean