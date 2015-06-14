#!/bin/bash

#TODO Flag Handling
#TODO File Handling
#TODO Tasks Execution
#TODO Task: Align
#TODO Task: Cluster
#TODO Task: Abund (rarefaction, shannon_chao, abund stats)
#TODO Task: Subsampling (run subsampler on given directory of fasta files)
#TODO Task: Rep (get rep sequences proportional to OTU size above cutoff
#TODO Task: Blast (cultured, uncultured, combine res)
#TODO Task: Tree
#TODO Task: PCoA
#TODO Task: Pipeline
#TODO Task: Retrieve
#TODO Script Refinement

#TODO Move blast databases to location usable by others
# check blast install folders?

#TODO Pack up with mac programs, and extreme compression of linux execs for init

#Testing variables
LOC="" #default local
TASK="" #if not specified default to print help text
TOOL="" #if not specified print options for task
ARGS="" #if not specified use default args set by me
INP="" #if not specified don't run
NAME="" #if not specified use filename -extension
RES_C="" #if not specified use defaults set by me (based on task)

#TODO: Function to copy programs to the cluster
#function init_auto_task()
#{
#}

#Help text function
#TODO: Write help text
function print_help()
{
cat >&2 << EOF
Help text goes here at some point...
EOF
}

#Flag Capture (based on my SlurmGraphing Config Script
for i in "$@"
do
case $i in
	hpc) #Run the task on the hpc cluster at USU
		LOC="hpc"
		shift
	;;
	align)
		TASK="align"
		shift
	;;
	cluster)
		TASK="cluster"
		shift
	;;
	abund)
		TASK="abund"
		shift
	;;
	rare|rarefaction)
		TASK="rare"
		shift
	;;
	sc|shannon_chao)
		TASK="sc"
		shift
	;;
	subsample)
		TASK="sub"
		shift
	;;
	rep)
		TASK="rep"
		shift
	;;
	blast)
		TASK="blast"
		TOOL="blast"
		shift
	;;
	tree)
		TASK="tree"
		shift
	;;
	pcoa)
		TASK="pcoa"
		shift
	;;
	chop)
		TASK="chop"
		shift
	;;
	pipeline)
		#TODO: Find way to list all the tools for each step
		TASK="pipeline"
		shift
	;;
	get)
		TASK="get"
		shift
	;;
	help)
		TASK="help"
	;;
	muscle|muscle-mp)
		TOOL="$i"
		shift
	;;
	mothur)
		TOOL="mothur"
		shift
	;;
	rdp|RDP)
		TOOL="rdp"
		shift
	;;
	fungene)
		TOOL="fungene"
		shift
	;;
	-c=*)
		RES_C="${i#*=}"
		shift
	;;
	init)
		#TODO: Check if programs are on the cluster already
		#if not copy/configure them for use
		shift
	;;
	*)
		#1 Check if it's a file or directory
		if [[ -e "$i" ]] || [[ -d "$i" ]]; then
			if [[ -z "$INP" ]]; then
				INP="$i"
			else
				INP="$INP;$i"
			fi
			continue
		fi
		#2 Check if it's an argument for a tool
		# Args required for certain task/tool:
		#   Task: subsample - num_seqs
		#   Task: rep - min_size
		#   Task: chop - num_bp, front/back
		# Cutoff is required but can be set to a default value (90%)
		#   Task: cluster, blast, pipeline - cutoff
		#4 Get confused and halt errything
		shift
	;;
esac
done

#Set defaults for un-specified flags
if [[ -z "$LOC" ]]; then
	LOC="local"
fi

if [[ -z "$TASK" ]]; then
	TASK="help"
fi

if [[ -z "$TOOL" ]] && [[ "$TASK" != "help" ]]; then
	TASK="tool-help"
fi

#TODO: Check for required arguments, set cutoff if needed

if [[ -z "$INP" ]]; then
	echo "Error: No input files found... Quitting."
	exit
fi

if [[ -z "$NAME" ]]; then
	#Take a guess at the name based on the input file
	NAME=$(echo $INP | sed 's/\/.*\///g' | sed 's/\..*//g')
fi

if [[ -z "$RES_C" ]]; then
	case $TOOL in
		muscle|fungene)
			RES_C="1"
		;;
		muscle-mp|mothur|rdp|RDP)
			RES_C="4"
		;;
	esac
	
	case $TASK in
		rare|sc|blast|pipeline)
			RES_C="4"
		;;
		abund|subsample|rep|tree|pcoa|get)
			RES_C="1"
	esac
fi

#View the testing vars
echo "$LOC - $TASK - $TOOL - $ARGS - $INP - $NAME - $RES_C"

#Notes
#Execution Steps
#Check for location
#Check for task
#Check for tool
#Check for arguments
#Check for input files
#Check for resource request
#Perform task

#Zip up results for getting
#./auto_task.sh get date_name_task /path/to/save/to :: will copy results archive to compy

# Running multiple commands over ssh connection
#Login to cluster
#read -p "A Number: " ANUM
#ANUM=$(echo $ANUM | awk '{print toupper($0)}')
#ssh -t -t -l $ANUM login.rc.usu.edu << EOF
#Create work directory (task_date)
#mkdir ~/"$(date +'%y-%m-%d')"_"$name"_"$task"
#Create files needed for running job
#Submit job
#Logout
#EOF
