# docker-slate for alpine

### Useage
1. make dir example: `docker-slate`
2. cd `docker-slate` and download the Dockerfile
3. download `slate` project
4. move `slate` folder all file to `docker-slate/slate` folder
5. cd `Dockerfile` folder
6. run `docker build -t=repository-name ./` to build image
7. run `docker run --name salte -v $PWD/slate/source:/usr/src/app/source -p 4567:4567 -d repository-name` to start slate
8. visit `http://localhost:4567/`