#!/bin/bash

#TODO Flag Handling (Mostly Done)
#TODO File Handling (Mostly Done)
#TODO Tasks Execution (Create sequences for tasks/tools
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

#Flag variables
LOC="" #default local
TASK="" #if not specified default to print help text
TOOL="" #if not specified print options for task
ARGS="" #if not specified use default args set by me
INP="" #if not specified don't run
NAME="" #if not specified use filename -extension
RES_C="" #if not specified use defaults set by me (based on task)
HELP=false

#Attempt to find where auto_task is located
AT_DIR=$(locate auto_task.sh | sed 's/\/auto_task.sh//g')

#System variables
SCRIPTS="$AT_DIR"/resources/scripts
PROGRAMS="$AT_DIR"/resources/programs
JOB_FILES="$AT_DIR"/resources/job_files

SEQUENCE=""

#TODO: Function to copy programs to the cluster
#function init_auto_task()
#{
#}

#Help text function
#TODO: Write help text for basic, task, and tool help functions
function basic_help()
{
cat >&2 << EOF
basic_help function
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
		LOC="hpc"
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
		#TODO: Go through all args again to create a sequence of tasks
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
		LOC="hpc"
		shift
	;;
	fungene)
		TOOL="fungene"
		LOC="hpc"
		shift
	;;
	-c=*)
		RES_C="${i#*=}"
		shift
	;;
	init)
		#TODO: Check if programs are on the cluster already
		#if not copy/configure them for use
		#Add an alias to make it easy to use
		#Generate SSH keys between computer and cluster to make everything easier
		#ssh-keygen -f ~/.ssh/auto_task_key -t rsa -N ''
		#cat ~/.ssh/auto_task_key.pub | ssh $ANUM@login.rc.usu.edu "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
		#ssh-add ~/.ssh/auto_task_key
		#Prompt for an A number and save it to the resources directory
		#source that file when HPC goings on are about to happen
		#'read -p "Enter A Number: " ANUM'
		echo "alias auto_task='$AT_DIR/auto_task.sh'" >> ~/.bashrc
		exit
	;;
	name=*)
		NAME="${i#*=}"
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
			shift
			continue
		fi
		
		#2 Check if it's an argument for a tool
		case $i in
			cutoff=*.*|seqs=*|otusize=*|hits=*|bps=*|pos=*|gene=*)
				if [[ -z "$ARGS" ]]; then
					ARGS="$i"
				else
					ARGS="$ARGS;$i"
				fi
				shift
				continue
			;;
		esac
		
		#3 Get confused and halt errything
		basic_help
		exit
	;;
esac
done

#Var printout
echo "Before assignment: "
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

#TODO: Argument Checking
if [[ -z "$INP" ]]; then
	echo "Error: No input files or directories found"
	exit
fi

if [[ -z "$NAME" ]]; then
	NAME="$TASK-$TOOL-$(date +%s)"
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

#Do task specific checking (i.e. required args and defaults that can be set)

#Defaults that can be set: num_hits for blast, cutoff for cluster & pipeline
#Defaults required: num_seqs for subsample, otusize for rep, bps and front/back for chop

#If RDP or Fungene were selected check to make sure gene=* was filled in
#  and if it has a valid value (list $PROGRAMS/fungene_pipeline/resources)
if [[ $TOOL == "rdp" || $TOOL == "fungene" ]] && [[ $ARGS != *"gene"* ]]; then
	echo "Error: $TASK requires a gene to be specified"
	exit
	
fi

if [[ $TOOL == "rdp" || $TOOL == "fungene" ]] && [[ $ARGS == *"gene"* ]]; then
	split_arg=($(echo $ARGS | sed 's/;/ /g'))
	for i in "${split_arg[@]}"; do
		if [[ $i == *"gene"* ]]; then
			sent_gene=$(echo $i | sed 's/gene=//g')
		fi
	done
	
	if [[ -z $sent_gene ]]; then
		echo "Error: Couldn't find the specified gene"
		exit
	fi
	
	GENES=($(ls $PROGRAMS/fungene_pipeline/resources/ | sed 's/.*resources\/programs\/fungene_pipeline\/resources\///g'))
	found=false
	
	case "${GENES[@]}" in *"$sent_gene"*) found=true ;; esac
	if [[ $found == false ]]; then
		echo "Error: $sent_gene is not a valid gene"
		echo "Valid genes are:"
		echo "${GENES[@]}"
		exit
	fi
fi

echo "After assignment: "
printf "%-5s %-8s %-9s %-12s %-13s %-2s %-5s %s\n" "Loc" "Task" "Tool" "Args" "Name" "C" "Help" "Input"
printf "%-5s %-8s %-9s %-12s %-13s %-2s %-5s %s\n\n" "$LOC" "$TASK" "$TOOL" "$ARGS" "$NAME" "$RES_C" "$HELP" "$INP"
echo

#Notes
#Execution Steps
#Check for location
#Check for task
#Check for tool
#Check for arguments
#Check for input files
#Check for resource request
#Perform task
#If not local zip the results


#Location dependant

#A Sequence of commands starts with creating a working directory, and results directory
#Then picks up location, task, and tool specific commands
if [[ $LOC == "hpc" ]]; then
	source $AT_DIR/resources/ANUM.sh
	#TASK: Run commands to create directory and scp input files over first
	#  Sequence will only have task / tool commands
	#TASK: Swap references to fremont over to usu cluster
	ssh -i ~/.ssh/auto_task_key -l "mike" -p 7389 fremont.bluezone.usu.edu "
	echo Creating auto_task-$NAME directory;
	mkdir /projects/$ANUM/auto_task-$NAME;
	echo Creating results directory;
	mkdir /projects/$ANUM/auto_task-$NAME/results;
	echo Transferring Input File;
	"
	
	#TASK: Set this transfer up to do all files in $INP
	for f in $(echo $INP | sed 's/;/\n/g'); do
		scp -i ~/.ssh/auto_task_key -P 7389 $f mike@fremont.bluezone.usu.edu:/projects/$ANUM/auto_task-$NAME/
		f_no_e=$(echo $f | sed 's/\..*//g')
		case $TASK in
			align)
				case $TOOL in
				muscle)
					SEQUENCE+="cd /projects/$ANUM/auto_task-$NAME/;"
					SEQUENCE+="echo '#!/bin/bash' > submit-$f_no_e.sh;
								echo '#SBATCH --name=auto_task-$NAME' >> submit-$f_no_e.sh;
								echo '/projects/$ANUM/auto_task/resources/programs/muscle -in $f -out results/"$f_no_e"_aligned.fasta' >> submit-$f_no_e.sh;
								echo 'tar -cvf - results | gzip -c - > $NAME-results.tar' >> submit-$f_no_e.sh;"
					SEQUENCE+="cat submit-$f_no_e.sh;"
				;;
				#muscle-mp)
				#;;
				#rdp)
				#;;
				#fungene)
				#;;
				esac
			;;
			#cluster)
			#;;
			#abund)
			#;;
			#rare)
			#;;
			#sc)
			#;;
			#sub)
			#;;
			#rep)
			#;;
			#blast)
			#;;
			#tree)
			#;;
			#pcoa)
			#;;
			#chop)
			#;;
			#pipeline)
			#;;
			#get)
			#;;
		esac
	done
	
	#Finally the Sequence needs to zip results up if it's not running local
else
	SEQUENCE+=('mkdir $(pwd)/auto_task-$NAME')
	SEQUENCE+=('cd $(pwd)/auto_task-$NAME')
	
	#The Sequence then needs to pick up the proper set of commands to run
	case $TASK in
		align)
			case $TOOL in
			muscle)
				SEQUENCE+=("$PROGRAMS/muscle -in $INP -out $(echo $INP | sed 's/\..*//g')_aligned.fasta")
			;;
			#muscle-mp)
			#;;
			#rdp)
			#;;
			#fungene)
			#;;
			esac
		;;
		#cluster)
		#;;
		#abund)
		#;;
		#rare)
		#;;
		#sc)
		#;;
		#sub)
		#;;
		#rep)
		#;;
		#blast)
		#;;
		#tree)
		#;;
		#pcoa)
		#;;
		#chop)
		#;;
		#pipeline)
		#;;
		#get)
		#;;
	esac
fi

#Execute the sequence
if [[ $LOC = "hpc" ]]; then
	ssh -t -t -i ~/.ssh/auto_task_key -l "mike" -p 7389 fremont.bluezone.usu.edu "$SEQUENCE"
else
	eval $SEQUENCE
fi

echo $SEQUENCE

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
