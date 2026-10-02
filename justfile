default: run-all

run file="examples/00_hello.ores":
    bash scripts/run.sh {{file}}

run-all:
    bash scripts/run-all.sh

source-ref:
    cat SOURCE_REF

keyword-demos:
    bash scripts/run-keyword-demos.sh


feature-demos:
    bash scripts/run-feature-demos.sh
