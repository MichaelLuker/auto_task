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
HELP=false

#TODO: Function to copy programs to the cluster
#function init_auto_task()
#{
#}

#Help text function
#TODO: Write help text for basic, task, and tool help functions
function basic_help()
{
cat >&2 << EOF
basic_help() function
EOF
}

#Print task specific help
function task_help()
{
	echo "$1 in task_help()"
	
	#case $1 in
	#	align)
	#	;;
	#	cluster)
	#	;;
	#	abund)
	#	;;
	#	rare)
	#	;;
	#	sc)
	#	;;
	#	sub)
	#	;;
	#	rep)
	#	;;
	#	blast)
	#	;;
	#	tree)
	#	;;
	#	pcoa)
	#	;;
	#	chop)
	#	;;
	#	pipeline)
	#	;;
	#	get)
	#	;;
	#esac
}

function tool_help()
{
	echo "$1 in tool_help()"
	
	#case $1 in
	#	muscle)
	#	;;
	#	muscle-mp)
	#	;;
	#	mothur)
	#	;;
	#	fungene)
	#	;;
	#	rdp)
	#	;;
	#esac
}

#Flag capture
for i in "$@"
do
case $i in
	hpc)
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
		HELP=true
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

#Var printout
printf "%-5s %-8s %-9s %-12s %-13s %-2s %-5s %s\n" "Loc" "Task" "Tool" "Args" "Name" "C" "Help" "Input"
printf "%-5s %-8s %-9s %-12s %-13s %-2s %-5s %s\n\n" "$LOC" "$TASK" "$TOOL" "$ARGS" "$NAME" "$RES_C" "$HELP" "$INP"

#Check if help was requested
if [[ $HELP == true ]]; then
	if [[ ! -z "$TASK" ]]; then
		task_help "$TASK"
	fi
	if [[ ! -z "$TOOL" ]]; then
		tool_help "$TOOL"
	fi
	if [[ -z "$TASK" ]] && [[ -z "$TOOL" ]]; then
		basic_help
	fi
	exit
fi

#Set defaults for un-specified flags
if [[ -z "$LOC" ]]; then
	LOC="local"
fi

if [[ -z "$TASK" ]]; then
	echo "Error: Need a task to perform"
	# basic_help ??
	exit
fi

#If a task is specified but no tool, list possible tools for that task
# sub, rep, blast, tree, pcoa, get, chop don't need a tool specified
if [[ -z "$TOOL" ]] && [[ ! -z "$TASK" ]]; then
	case $TASK in
		align|cluster|abund|rare|sc|pipeline)
			echo "Error: A tool must be specified for task '$TASK'"
			task_help "$TASK"
			exit
		;;
	esac
fi

#TODO: Check for required arguments, set cutoff if needed
if [[ -z "$INP" ]]; then
	echo "Error: No input files or directories found"
	exit
fi

if [[ -z "$NAME" ]]; then
	#Take a guess at the name based on the input file
	NAME=$(echo $INP | sed 's/\/.*\///g' | sed 's/\..*//g')
	
	#If that didn't work then set it to be unique
	if [[ -z "$NAME" ]];then
		NAME="$TASK-$TOOL-$(date +%s)"
	fi
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

printf "%-5s %-8s %-9s %-12s %-13s %-2s %-5s %s\n" "Loc" "Task" "Tool" "Args" "Name" "C" "Help" "Input"
printf "%-5s %-8s %-9s %-12s %-13s %-2s %-5s %s\n\n" "$LOC" "$TASK" "$TOOL" "$ARGS" "$NAME" "$RES_C" "$HELP" "$INP"

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
