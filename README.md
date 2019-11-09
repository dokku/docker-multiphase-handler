# docker-multiphase-handler

Enables proper handling of multiphase dockerfiles

## Usage

Using the following dockerfile as an example:

```Dockerfile
FROM ubuntu AS named-stage

RUN some-command

# stage unnamed
FROM ubuntu

RUN another-command

FROM alpine AS built-app
```

Valid flags:

- `--file | -f`: Name of the Dockerfile (Default is `PATH/Dockerfile`)
- `--prefix | -p`: Prefix for unnamed stages (Default is `unnamed-`)

### List Stages

Lists all stages in a dockerfile. If the stage is unnamed, then a temporary stage name is output.

```shell
docker-multiphase-executor list-stages
```

```
named-stage
unnamed-1
built-app
```

### Check if Dockerfile needs rewrite

Exit `0` if the specified Dockerfile does not need to be rewritten, exits `1` if it does need to be rewritten

```shell
docker-multiphase-executor needs-rewrite
```

### Rewrite Dockerfile

Rewrites the specified Dockerfile to ensure each stage is named. May reformat dockerfile and remove comments.

```shell
docker-multiphase-executor rewrite
```

Outputs the following to stdout.

```Dockerfile
FROM ubuntu AS named-stage

RUN some-command

FROM ubuntu AS unnamed-1

RUN another-command

FROM alpine AS built-app
```

The flag `--output-path` can be specified to specify a path to write it to.
