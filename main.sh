#!/usr/bin/env bash
src="test-cugraph-louvain"
out="$HOME/Logs/$src$1.log"
ulimit -s unlimited
printf "" > "$out"

# Configuration
: "${CUDA_VERSION:=11.4}"

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
  # Convert the graph in MTX format to CSV (space-separated)
  stdbuf --output=L printf "Converting $1 to $1.csv ...\n"           | tee -a "$out"
  lines="$(node process.js header-lines "$1")"
  echo "src dst" > "$1.csv"
  tail -n +$((lines+1)) "$1" >> "$1.csv"
  # Run cuGraph louvain
  stdbuf --output=L printf "Running cuGraph Louvain on $1.csv ...\n" | tee -a "$out"
  stdbuf --output=L python3 main.py "$1.csv" "$4"               2>&1 | tee -a "$out"
  stdbuf --output=L printf "\n\n"                                    | tee -a "$out"
  # Clean up
  rm -rf "$1.csv"
}

# Run cuGraph Louvain on each graph
runEach() {
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

# Run 5 times
for i in {1..5}; do
  runEach
done

# Signal completion
curl -X POST "https://maker.ifttt.com/trigger/puzzlef/with/key/${IFTTT_KEY}?value1=$src$1"
