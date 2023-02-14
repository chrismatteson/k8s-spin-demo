FROM --platform=${BUILDPLATFORM} rust:1.59 AS build
WORKDIR .
COPY . .
RUN rustup target add wasm32-wasi && cargo build --target wasm32-wasi --release

FROM scratch
COPY --from=build ./target/wasm32-wasi/release/example_app.wasm .
COPY --from=build ./spin.toml .
