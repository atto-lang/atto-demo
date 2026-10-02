default: run-all

run file="examples/00_hello.ores":
    bash scripts/run.sh {{file}}

run-all:
    bash scripts/run-all.sh

source-ref:
    cat SOURCE_REF
