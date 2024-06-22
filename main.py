import os
import sys
import time
import rmm
import cudf
import cugraph


# Initialize RMM pool
mode = sys.argv[3]
print("Initializing RMM pool...", flush=True)
if mode == "managed":
  pool = rmm.mr.PoolMemoryResource(rmm.mr.ManagedMemoryResource(), initial_pool_size=2**36)
else:
  pool = rmm.mr.PoolMemoryResource(rmm.mr.CudaMemoryResource(), initial_pool_size=2**36)
rmm.mr.set_current_device_resource(pool)

# Read graph from file
file = os.path.expanduser(sys.argv[1])
print("Reading graph from file: {}".format(file), flush=True)
gdf  = cudf.read_csv(file, delimiter=' ', names=['src', 'dst'], dtype=['int32', 'int32'])
print("Symmetrizing graph...", flush=True)
gdf  = cugraph.symmetrize_df(gdf, 'src', 'dst', None, False, False)
gdf["data"] = 1.0  # Add edge weights
G    = cugraph.Graph()
print("Creating cuGraph graph...", flush=True)
G.from_cudf_edgelist(gdf, source='src', destination='dst', edge_attr='data', renumber=True)

# Run Leiden
print("Running Leiden (first)...", flush=True)
parts, mod = cugraph.leiden(G)
for i in range(4):
  print("Running Leiden...", flush=True)
  t0 = time.time()
  parts, mod = cugraph.leiden(G)
  t1 = time.time()
  print("Leiden modularity: {:.6f}".format(mod), flush=True)
  print("Leiden took: {:.6f} s".format(t1-t0), flush=True)

# Save communities to file
comm = os.path.expanduser(sys.argv[2])
print("Saving communities to file: {}".format(comm), flush=True)
parts.to_csv(comm, sep=' ', header=False, index=False, chunksize=1e6)
