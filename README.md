# docker-slate for alpine

### Useage
1. download this repository
2. cd `docker-slate`
3. download `slate` project
4. move `slate` project folder all file to `docker-slate/slate` folder
5. cd to `Dockerfile` folder
6. run `docker build -t=slate ./` to build image named `slate` (volume maybe 208MB)
7. run `docker run --name salte -v $PWD/slate/source:/usr/src/app/source -p 4567:4567 -d slate` to start slate
8. visit `http://localhost:4567/`
