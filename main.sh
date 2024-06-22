#!/usr/bin/env bash
src="test-cugraph-louvain"
out="$HOME/Logs/$src$1.log"
ulimit -s unlimited
printf "" > "$out"

# Configuration
: "${CUDA_VERSION:=11.4}"

# Download tool to count disconnected communities
app="graph-count-disconnected-communities"
rm -rf $app
git clone https://github.com/ionicf/$app && echo ""
cd $app

# Fixed config
: "${KEY_TYPE:=uint32_t}"
: "${EDGE_VALUE_TYPE:=float}"
: "${MAX_THREADS:=64}"
# Define macros (dont forget to add here)
DEFINES=(""
"-DKEY_TYPE=$KEY_TYPE"
"-DEDGE_VALUE_TYPE=$EDGE_VALUE_TYPE"
"-DMAX_THREADS=$MAX_THREADS"
)

# Build tool
g++ ${DEFINES[*]} -std=c++17 -O3 -fopenmp main.cxx
mv a.out ../count.out
cd ..

# Download program
if [[ "$DOWNLOAD" != "0" ]]; then
  rm -rf $src
  git clone https://github.com/puzzlef/$src && echo ""
  cd $src
fi

# Install cuGraph
if [[ "$INSTALL" == "1" ]]; then
  conda create --name cugraph-env -y
  conda activate cugraph-env
  conda install -c rapidsai -c conda-forge -c nvidia cugraph cuda-version=$CUDA_VERSION -y
fi

# Run program
runCugraph() {
  # $1: input file name
  # $2: is graph weighted (0/1)
  # $3: is graph symmetric (0/1)
  # $4: memory manager (default/managed)
  opt2=""
  opt3=""
  if [[ "$2" == "1" ]]; then opt2="-w"; fi
  if [[ "$3" == "1" ]]; then opt3="-s"; fi
  # Convert the graph in MTX format to CSV (space-separated)
  stdbuf --output=L printf "Converting $1 to $1.csv ...\n"                          | tee -a "$out"
  lines="$(node process.js header-lines "$1")"
  echo "src dst" > "$1.csv"
  tail -n +$((lines+1)) "$1" >> "$1.csv"
  # Run cuGraph leiden, and save the obtained communities
  stdbuf --output=L printf "Running cuGraph Leiden on $1.csv ...\n"                 | tee -a "$out"
  stdbuf --output=L python3 main.py "$1.csv" "$1.clstr" "$3"                   2>&1 | tee -a "$out"
  # Count disconnected communities
  stdbuf --output=L printf "Counting disconnected communities ...\n"                | tee -a "$out"
  stdbuf --output=L ../count.out -i "$1" -m "$1.clstr" -k -r 0 "$opt2" "$opt3" 2>&1 | tee -a "$out"
  stdbuf --output=L printf "\n\n"                                                   | tee -a "$out"
  # Clean up
  rm -rf "$1.csv"
  rm -rf "$1.clstr"
}

runAll() {
  # runCugraph "$HOME/Data/web-Stanford.mtx"    0 0 default
  runCugraph "$HOME/Data/indochina-2004.mtx"  0 0 default
  runCugraph "$HOME/Data/uk-2002.mtx"         0 0 default
  # runCugraph "$HOME/Data/arabic-2005.mtx"     0 0 managed
  # runCugraph "$HOME/Data/uk-2005.mtx"         0 0 managed
  # runCugraph "$HOME/Data/webbase-2001.mtx"    0 0 managed
  # runCugraph "$HOME/Data/it-2004.mtx"         0 0 managed
  # runCugraph "$HOME/Data/sk-2005.mtx"         0 0 managed
  runCugraph "$HOME/Data/com-LiveJournal.mtx" 0 1 default
  runCugraph "$HOME/Data/com-Orkut.mtx"       0 1 default
  runCugraph "$HOME/Data/asia_osm.mtx"        0 1 default
  runCugraph "$HOME/Data/europe_osm.mtx"      0 1 default
  runCugraph "$HOME/Data/kmer_A2a.mtx"        0 1 default
  runCugraph "$HOME/Data/kmer_V1r.mtx"        0 1 default
}

runAll

# Signal completion
curl -X POST "https://maker.ifttt.com/trigger/puzzlef/with/key/${IFTTT_KEY}?value1=$src$1"
