#!/bin/bash -l

#SBATCH -q debug 
#SBATCH -C cpu
#SBATCH -A m4293 # Sparsitute project (A Mathematical Institute for Sparse Computations in Science and Engineering)

#SBATCH -t 0:10:00

#SBATCH -N 8
#SBATCH -J matmul
#SBATCH -o slurm.matmul.o%j

module swap PrgEnv-gnu PrgEnv-intel
module load python

SYSTEM=perlmutter_cpu
CORE_PER_NODE=128 # Never change. Specific to the system
PER_NODE_MEMORY=256 # Never change. Specific to the system
N_NODE=4
PROC_PER_NODE=8
N_PROC=$(( $N_NODE * $PROC_PER_NODE ))
CORE_PER_PROC=$(( $CORE_PER_NODE / $PROC_PER_NODE )) 
THREAD_PER_PROC=$(( $CORE_PER_PROC * 2 )) # Set number of threads to be twice the number of physical cores ( using logical cores )
PER_PROC_MEM=$(( $PER_NODE_MEMORY / $PROC_PER_NODE - 2)) #2GB margin of error
export OMP_NUM_THREADS=$THREAD_PER_PROC
export MKL_NUM_THREADS=$THREAD_PER_PROC
#export OMP_PLACES=threads
#export OMP_PROC_BIND=spread

P1=1
P2=1
P3=1
N1=50000
N2=50000
N3=5000

#for ALG in [ "matmul", "matmul1gen", "matmul1comm" ]; do
#for ALG in matmul
for ALG in matmul1gen matmul1comm 
do
    for IMPL in cpp python
    #for IMPL in cpp
    do
        echo $ALG, $IMPL
        if [ "$ALG" == "matmul" ]; then
            if [ "$N_PROC" -eq 8 ]; then
                P1=2
                P2=2
                P3=2
            elif [ "$N_PROC" -eq 16 ]; then
                P1=4
                P2=2
                P3=2
            elif [ "$N_PROC" -eq 32 ]; then
                P1=4
                P2=4
                P3=2
            elif [ "$N_PROC" -eq 64 ]; then
                P1=4
                P2=4
                P3=4
            elif [ "$N_PROC" -eq 128 ]; then
                P1=8
                P2=4
                P3=4
            elif [ "$N_PROC" -eq 256 ]; then
                P1=8
                P2=8
                P3=4
            elif [ "$N_PROC" -eq 512 ]; then
                P1=8
                P2=8
                P3=8
            elif [ "$N_PROC" -eq 1024 ]; then
                P1=16
                P2=8
                P3=8
            fi
        elif [ "$ALG" == "matmul1gen" ]; then
            P1=$N_PROC
            P2=1
            P3=1
        elif [ "$ALG" == "matmul1comm" ]; then
            P1=$N_PROC
            P2=1
            P3=1
        fi

        STDOUT_FILE=$SCRATCH/nystrom/"$ALG"_"$IMPL"_"$N_NODE"_"$N_PROC"_"$P1"x"$P2"x"$P3"

        PY=$HOME/Codes/nystrom-distributed/tests/matmul-test.py
        BIN=$HOME/Codes/nystrom-distributed/build/c_matmul/matmul

        if [ "$IMPL" == "cpp" ]; then
            srun -N $N_NODE -n $N_PROC -c $THREAD_PER_PROC --ntasks-per-node=$PROC_PER_NODE --cpu-bind=cores \
                $BIN -p1 $P1 -p2 $P2 -p3 $P3 -n1 $N1 -n2 $N2 -n3 $N3 -alg $ALG &> $STDOUT_FILE
            #srun -N $N_NODE -n $N_PROC -c $THREAD_PER_PROC --ntasks-per-node=$PROC_PER_NODE --cpu-bind=cores \
                #check-hybrid.gnu.pm | sort -k4,4n -k6,6n &> blah.txt
        elif [ "$IMPL" == "python" ]; then
            srun -N $N_NODE -n $N_PROC -c $THREAD_PER_PROC --ntasks-per-node=$PROC_PER_NODE --cpu-bind=cores \
                python $PY -p1 $P1 -p2 $P2 -p3 $P3 -n1 $N1 -n2 $N2 -n3 $N3 -alg $ALG &> $STDOUT_FILE
        fi
    done
done
