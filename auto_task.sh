#!/bin/bash

#Flag variables
TASK="" #if not specified default to print help text
TOOL="" #if not specified print options for task
ARGS="" #if not specified use default args set by me
INP="" #if not specified don't run
NAME="" #if not specified use filename -extension
RES_C="" #if not specified use defaults set by me (based on task)
HELP=false

#Attempt to find where auto_task is located
AT_DIR=$(find ~ -name "auto_task.sh" | sed 's/\/auto_task.sh//g')

SEQUENCE=""

#Help text functions
function basic_help()
{
cat >&2 << EOF
Possible tasks:	align, cluster, rare, shannon_chao,
				blast, pipeline, get

Possible tools: muscle, mothur, rdp, fungene, combo

Extra options:	cutoff, hits, gene, name

Example commands:
	auto_task align muscle input.fasta
	auto_task cluster mothur input_aligned.fasta
	auto_task pipeline combo input.fasta

To see specific information on a task use help, i.e.
	auto_task help align
	auto_task help abund
	auto_task help pipeline
EOF
}

#Print task specific help
function task_help()
{
	case $1 in
		align)
cat >&2 << EOF
Task:	align
Tools:	muscle, rdp, fungene
Input:	fasta files
Output:	aligned fasta files

i.e.	auto_task align muscle input.fasta
	auto_task align rdp input.fasta gene=RRNA_16S_BACTERIA
	auto_task align fungene input.fasta gene=nifh
EOF
		;;
		cluster)
cat >&2 << EOF
Task:	cluster
Tools:	mothur, rdp, fungene
Input:	aligned fasta file
Output:	names and clust files

i.e.	auto_task cluster mothur aligned_input.fasta
	auto_task cluster rdp aligned_input.fasta
	auto_task cluster fungene aligned_input.fasta cutoff=0.05
EOF
		;;
		rare)
cat >&2 << EOF
Task:	rarefaction
Tools:	mothur, rdp, fungene
Input:	list or clust file
Output:	text file

i.e.	auto_task rare mothur aligned_input_95.list
	auto_task rare rdp aligned_input_97.clust
EOF
		;;
		sc)
cat >&2 << EOF
Task:	shannon_chao
Tools:	rdp, fungene
Input:	clust files
Output:	text file

i.e.	auto_task shannon_chao rdp aligned_input_95.clust
	auto_task shannon_chao fungene aligned_input_95.clust
EOF
		;;
		blast)
cat >&2 << EOF
Task:	blast
Tools:	none
Input:	query fasta file, max number of hits to keep
Output:	fasta files for a cultured and uncultured search, and a combo of results and query

i.e.	auto_task blast query_file.fasta
	auto_task blast query_file.fasta hits=5
EOF
		;;
		pipeline)
cat >&2 << EOF
Task:	pipeline
Tools:	rdp, fungene, combo(muscle/mothur)
Input:	unaligned fasta
Output:	alignment, clustering, rarefaction, (shannon_chao if fungene/rdp)

i.e.	auto_task pipeline rdp input.fasta gene=16S_BACTERIAL
	auto_task pipeline fungene input.fasta gene=nifh
EOF
		;;
		get)
cat >&2 << EOF
Task:	get
Tools:	none
Input:	name of job to get
Output: tar file of results from the job that has run on the HPC cluster

i.e.	auto_task get auto_task-align-muscle-1434691617
EOF
		;;
	esac
}

#Flag capture
for i in "$@"
do
case $i in
	align|cluster)
		TASK="$i"
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
	blast)
		TASK="blast"
		shift
	;;
	pipeline)
		TASK="pipeline"
		TOOL="fungene"
		shift
	;;
	get)
		if [[ -e "$AT_DIR/resources/CONFIG.sh" ]]; then
			source $AT_DIR/resources/CONFIG.sh
		else
			echo "Error: Cannot find $AT_DIR/resources/CONFIG.sh"
			echo "  auto_task may not have been initialized"
			exit
		fi
		
		for i in "$@"; do
			if [[ "$i" == *"auto_task"* ]]; then
				scp -i ~/.ssh/auto_task_key $ANUM@$LOGIN:$OUT/$i/*.tgz .
			fi
		done
		exit
	;;
	help)
		HELP=true
	;;
	muscle|mothur|combo)
		TOOL="$i"
		shift
	;;
	rdp|fungene)
		TOOL="$i"
		shift
	;;
	-c=*)
		RES_C="${i#*=}"
		shift
	;;
	init)
		# 1 Get A number and write it to file
		# 2 Create SSH key
		# 3 put key onto server
		# 4 copy over the resource compression
		# 5 extract it
		# 6 add an alias to user bashrc
		
		if [[ ! -e "$AT_DIR/resources/CONFIG.sh" ]]; then
			read -p "Enter your A number: " ANUM
			ANUM=$(echo $ANUM | awk '{print toupper($0)}')
			
			read -p "Enter the hostname to log in to (i.e. login.rc.usu.edu): " LOGIN
			
			read -p "Enter the directory to use on cluster for auto_task i.e. /projects/A01515202 or leave blank to use home directory: " DIR
			
			if [[ -z $DIR ]]; then
				DIR=/home/"$ANUM"
				RES=/home/"$ANUM"/resources
				OUT=$DIR
			fi
			
			echo "Generating keys for Server"
			ssh-keygen -f ~/.ssh/auto_task_key -t rsa -N ''
			cat ~/.ssh/auto_task_key.pub | ssh $ANUM@$LOGIN "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
			ssh-add ~/.ssh/auto_task_key
			
			echo "Writing options to file"
			echo '#!/bin/bash' > $AT_DIR/resources/CONFIG.sh
			echo "ANUM=$ANUM" >> $AT_DIR/resources/CONFIG.sh
			EMAIL=$(ssh -i ~/.ssh/auto_task_key $ANUM@$LOGIN "/rc/tools/utils/lib/useremaillookup.sh $ANUM | cut -d '<' -f 2 | sed 's/>//g'")
			echo "EMAIL=$EMAIL" >> $AT_DIR/resources/CONFIG.sh
			echo "LOGIN=$LOGIN" >> $AT_DIR/resources/CONFIG.sh
			echo "RES=$RES" >> $AT_DIR/resources/CONFIG.sh
			echo "OUT=$OUT" >> $AT_DIR/resources/CONFIG.sh
			
			echo "Copying programs to HPC cluster: /projects/$ANUM/resources"
			scp -i ~/.ssh/auto_task_key $AT_DIR/res.tar.xz $ANUM@$LOGIN:$DIR
			ssh -i ~/.ssh/auto_task_key $ANUM@$LOGIN "cd $DIR; tar -xvf res.tar.xz"
			
			echo "Configuring Fungene and RDP locations: /projects/$ANUM/resources/programs/fungene_pipeline/config.ini"
			ssh -i ~/.ssh/auto_task_key $ANUM@$LOGIN "
			echo '[pipeline]' > $RES/programs/fungene_pipeline/config.ini;
			echo 'resource_dir = $RES/programs/fungene_pipeline/resources' >> $RES/programs/fungene_pipeline/config.ini;
			echo 'blastx_db = #unused' >> $RES/programs/fungene_pipeline/config.ini;
			echo 'blastn_db = #unused' >> $RES/programs/fungene_pipeline/config.ini;
			echo 'distribute_jobs = false' >> $RES/programs/fungene_pipeline/config.ini;
			echo 'cmalign_cmd = $RES/programs/infernal-1.1.1/binaries/cmalign' >> $RES/programs/fungene_pipeline/config.ini;
			echo 'hmmalign_cmd = $RES/programs/hmmer-3/bin/hmmalign' >> $RES/programs/fungene_pipeline/config.ini;
			echo 'blast_cmd = $RES/programs/blast-2.2.26/bin/blastall' >> $RES/programs/fungene_pipeline/config.ini;
			echo 'formatdb_cmd = $RES/programs/blast-2.2.26/bin/formatdb' >> $RES/programs/fungene_pipeline/config.ini;
			echo 'parse_error_analysis_cmd = $RES/programs/fungene_pipeline/parseErrorAnalysis.py' >> $RES/programs/fungene_pipeline/config.ini;
			echo 'usearch_cmd = $RES/programs/usearch' >> $RES/programs/fungene_pipeline/config.ini;
			echo 'gridware_env_path=/usr/bin:/usr/sbin:/Software/bin #unused' >> $RES/programs/fungene_pipeline/config.ini;
			echo 'process_class_jar = $RES/programs/RDPTools/SeqFilters.jar' >> $RES/programs/fungene_pipeline/config.ini;
			echo 'cluster_jar = $RES/programs/RDPTools/Clustering.jar' >> $RES/programs/fungene_pipeline/config.ini;
			echo 'framebot_jar = $RES/programs/RDPTools/FrameBot.jar' >> $RES/programs/fungene_pipeline/config.ini;
			echo 'alignment_tools_jar = $RES/programs/RDPTools/AlignmentTools.jar' >> $RES/programs/fungene_pipeline/config.ini;
			echo 'abundance_jar = $RES/programs/RDPTools/AbundanceStats.jar' >> $RES/programs/fungene_pipeline/config.ini;
			"
			
			echo "Writing auto_task alias"
			echo "alias auto_task='$AT_DIR/auto_task.sh'" >> ~/.bashrc
			
			echo "Initialization complete"
			echo "Close and re-open this terminal, or start a new terminal to use alias."
			exit
		else
			echo "Error: $AT_DIR/resources/CONFIG.sh already exists, init has been run before."
			exit
		fi
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
			cutoff=*.*|hits=*|gene=*|tdb=*|dbp=*)
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

if [[ -e "$AT_DIR/resources/CONFIG.sh" ]]; then
	source $AT_DIR/resources/CONFIG.sh
else
	echo "Error: Cannot find $AT_DIR/resources/CONFIG.sh"
	echo "  auto_task may not have been initialized"
	exit
fi

#Check if help was requested
if [[ $HELP == true ]]; then
	if [[ ! -z "$TASK" ]]; then
		task_help "$TASK"
	else
		basic_help
		
	fi
	exit
fi

#Set defaults for un-specified flags
if [[ -z "$LOC" ]]; then
	LOC="hpc"
fi

if [[ -z "$TASK" ]]; then
	echo "Error: Need a task to perform"
	basic_help
	exit
fi

#If a task is specified but no tool, list possible tools for that task
# sub, rep, blast, tree, pcoa, get, chop don't need a tool specified
if [[ -z "$TOOL" ]] && [[ ! -z "$TASK" ]]; then
	case $TASK in
		align|cluster|rare|sc|pipeline)
			echo "Error: A tool must be specified for task '$TASK'"
			task_help "$TASK"
			exit
		;;
	esac
fi

if [[ -z "$INP" ]]; then
	echo "Error: No input files or directories found"
	exit
fi

if [[ -z "$NAME" ]]; then
	if [[ ! -z $TOOL ]]; then
		NAME="$TASK-$TOOL-$(date +%s)"
	else
		NAME="$TASK-$(date +%s)"
	fi
fi

if [[ -z "$RES_C" ]]; then
	case $TASK in
		align|cluster|rare|sc|blast|pipeline)
			RES_C="4"
		;;
		get)
			RES_C="1"
	esac
	
	case $TOOL in
		muscle|fungene)
			RES_C="1"
		;;
		mothur|rdp|combo)
			RES_C="4"
		;;
	esac
fi

#Do task specific checking (i.e. required args and defaults that can be set)

#Defaults that can be set: num_hits for blast, cutoff for cluster & pipeline
#Defaults required: num_seqs for subsample, otusize for rep, bps and front/back for chop

#If RDP or Fungene were selected check to make sure gene=* was filled in
#  and if it has a valid value (list $PROGRAMS/fungene_pipeline/resources)
if [[ $TOOL == "rdp" || $TOOL == "fungene" ]] && [[ $ARGS != *"gene"* ]]; then
	echo "Error: $TASK with $TOOL requires a gene to be specified"
	echo "Possible genes are:"
	GENES=($(ls $AT_DIR/resources/genes | sed 's/.*resources\/genes\///g'))
	echo "${GENES[@]}"
	exit
	
fi

if [[ $TOOL == "rdp" || $TOOL == "fungene" ]] && [[ $ARGS == *"gene"* ]]; then
	split_arg=($(echo $ARGS | sed 's/;/ /g'))
	for i in "${split_arg[@]}"; do
		if [[ $i == *"gene="* ]]; then
			sent_gene=$(echo $i | sed 's/.*gene=//g')
		elif [[ $i == *"cutoff="* ]]; then
			cutoff=$(echo $i | sed 's/.*cutoff=//g')
		fi
	done
	
	if [[ -z $sent_gene ]]; then
		echo "Error: Couldn't find the specified gene"
		exit
	fi
	
	GENES=($(ls $AT_DIR/resources/genes | sed 's/.*resources\/genes\///g'))
	found=false
	
	case "${GENES[@]}" in *"$sent_gene"*) found=true ;; esac
	if [[ $found == false ]]; then
		echo "Error: $sent_gene is not a valid gene"
		echo "Valid genes are:"
		echo "${GENES[@]}"
		exit
	fi
fi

if [[ $TASK == "blast" ]] && [[ $ARGS == *"hits"* ]]; then
	split_arg=($(echo $ARGS | sed 's/;/ /g'))
	for i in "${split_arg[@]}"; do
		if [[ $i == *"hits"* ]]; then
			hits=$(echo $i | sed 's/.*hits=//g')
		fi
	done
fi

if [[ $TOOL == "mothur" ]] || [[ $TOOL == "combo" ]] && [[ $ARGS == *"cutoff"* ]]; then
	split_arg=($(echo $ARGS | sed 's/;/ /g'))
	for i in "${split_arg[@]}"; do
		if [[ $i == *"cutoff"* ]]; then
			cutoff=$(echo $i | sed 's/.*cutoff=//g')
		fi
	done
fi

if [[ -z "$hits" ]]; then hits=5; fi
if [[ -z "$cutoff" ]]; then cutoff=0.1; fi

if [[ $TASK == "blast" ]] && [[ $ARGS == *"tdb"* ]]; then
	split_arg=($(echo $ARGS | sed 's/;/ /g'))
	for i in "${split_arg[@]}"; do
		if [[ $i == *"tdb"* ]]; then
			tdb=$(echo $i | sed 's/.*tdb=//g')
		fi
	done
fi

if [[ $TASK == "blast" ]] && [[ $ARGS == *"dbp"* ]]; then
	split_arg=($(echo $ARGS | sed 's/;/ /g'))
	for i in "${split_arg[@]}"; do
		if [[ $i == *"cutoff"* ]]; then
			dbp=$(echo $i | sed 's/.*dbp=//g')
		fi
	done
fi


if [[ -z "$tdb" ]]; then tdb="nt"; fi

if [[ $tdb == "nt" ]]; then blast="blastn";
elif [[ $tdb == "nr" ]]; then blast="blastp"; fi

if [[ -z "$dbp" ]]; then dbp="/projects/A01515202/blast_dbs/$tdb"; fi

#Notes
#Execution Steps
#  Check for task
#  Check for tool
#  Check for arguments
#  Check for input files
#  Check for resource request
#  Perform task
#  Zip the results

#A Sequence of commands starts with creating a working directory, and results directory
#Then picks up location, task, and tool specific commands
source $AT_DIR/resources/CONFIG.sh

ssh -i ~/.ssh/auto_task_key $ANUM@$LOGIN "
echo Creating auto_task-$NAME directory;
mkdir $OUT/auto_task-$NAME;
echo 'Transferring Input File(s)';
"

#Create commands for each input file that's to be run
for f in $(echo $INP | sed 's/;/\n/g'); do
	scp -i ~/.ssh/auto_task_key $f $ANUM@$LOGIN:$OUT/auto_task-$NAME/
	f_no_e=$(echo $f | sed 's/\..*//g')
	case $TASK in
		align)
			case $TOOL in
			muscle)
				SEQUENCE+="cd $OUT/auto_task-$NAME/;
				mkdir $f_no_e-results;"
				SEQUENCE+="echo 'Writing submission file';
				echo '#!/bin/bash' > submit-$f_no_e.sh;
				echo '$RES/programs/muscle -in $f -out $f_no_e-results/$f_no_e-aligned.fasta' >> submit-$f_no_e.sh;
				echo 'tar -cvf - $f_no_e-results | gzip -c - > $f_no_e-results.tgz' >> submit-$f_no_e.sh;
				"
				SEQUENCE+="echo 'Submitting job';
				sbatch --cpus-per-task=$RES_C --job-name=auto_task-$f_no_e --mail-type=END --mail-user=$EMAIL submit-$f_no_e.sh;"
			;;
			fungene|rdp)
				#1 Write the commands and options text files
				SEQUENCE+="cd $OUT/auto_task-$NAME/;
				echo 'Writing job files';
				echo -e 'dereplicate\tunaligned' >> commands-$f_no_e.txt;
				echo 'align' >> commands-$f_no_e.txt;
				echo -e 'explode_mapping\texpanded_mappings' >> commands-$f_no_e.txt;"
				
				SEQUENCE+="echo $sent_gene >> options-$f_no_e.txt;
				echo $OUT/auto_task-$NAME >> options-$f_no_e.txt;
				echo $OUT/auto_task-$NAME/$f_no_e-results >> options-$f_no_e.txt;
				echo $EMAIL >> options-$f_no_e.txt;
				echo $OUT/auto_task-$NAME/status-$f_no_e.txt >> options-$f_no_e.txt;
				echo $OUT/auto_task-$NAME/$f_no_e-results.tgz >> options-$f_no_e.txt;
				echo $OUT/auto_task-$NAME/mail_message.txt >> options-$f_no_e.txt;
				"
				
				#2 Write the submission script
				SEQUENCE+="echo '#!/bin/bash' >> submit-$f_no_e.sh;
				echo '. /rc/tools/utils/dkinit' >> submit-$f_no_e.sh;
				echo 'use Python-EPD' >> submit-$f_no_e.sh;
				"
				
				SEQUENCE+="echo python $RES/programs/fungene_pipeline/fgp_wrapper.py options-$f_no_e.txt commands-$f_no_e.txt $f >> submit-$f_no_e.sh;"
				
				#3 submit the script to run
				SEQUENCE+="echo 'Submitting job';
				sbatch --cpus-per-task=$RES_C --job-name=auto_task-$f_no_e --mail-type=END --mail-user=$EMAIL submit-$f_no_e.sh;"
			;;
			esac
		;;
		cluster)
			case $TOOL in
				fungene|rdp)
					#1 Write the commands and options text files
					SEQUENCE+="cd $OUT/auto_task-$NAME/;
					echo 'Writing job files';
					echo -e 'dereplicate\taligned' >> commands-$f_no_e.txt;
					echo -e 'distance\t$cutoff\t0.01\t#=GC_RF' >> commands-$f_no_e.txt;
					echo -e 'cluster\tcomplete\t0.01' >> commands-$f_no_e.txt;"
					
					SEQUENCE+="echo $sent_gene >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME/$f_no_e-results >> options-$f_no_e.txt;
					echo $EMAIL >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME/status-$f_no_e.txt >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME/$f_no_e-results.tgz >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME/mail_message.txt >> options-$f_no_e.txt;
					"
					
					#2 Write the submission script
					SEQUENCE+="echo '#!/bin/bash' >> submit-$f_no_e.sh;
					echo '. /rc/tools/utils/dkinit' >> submit-$f_no_e.sh;
					echo 'use Python-EPD' >> submit-$f_no_e.sh;
					"
					
					SEQUENCE+="echo python $RES/programs/fungene_pipeline/fgp_wrapper.py options-$f_no_e.txt commands-$f_no_e.txt $f >> submit-$f_no_e.sh;"
					
					#3 submit the script to run
					SEQUENCE+="echo 'Submitting job';
					sbatch --cpus-per-task=$RES_C --job-name=auto_task-$f_no_e --mail-type=END --mail-user=$EMAIL submit-$f_no_e.sh;"
				;;
				mothur)
					SEQUENCE+="cd $OUT/auto_task-$NAME/;
					mkdir $f_no_e-clustering;
					echo 'Writing job files';
					echo '#!/bin/bash' >> submit-$f_no_e.sh;
					echo -e 'cd $f_no_e-clustering' >> submit-$f_no_e.sh;
					echo -e 'cp ../$f .' >> submit-$f_no_e.sh;
					echo -e '$RES/programs/mothur/mothur \"#dist.seqs(fasta=$f, output=lt, processors=$RES_C)\"' >> submit-$f_no_e.sh;
					echo -e '$RES/programs/mothur/mothur \"#cluster.classic(phylip=$f_no_e.phylip.dist, cutoff=$cutoff)\"' >> submit-$f_no_e.sh;
					echo -e '$RES/programs/mothur/mothur \"#get.oturep(phylip=$f_no_e.phylip.dist, list=$f_no_e.phylip.an.list, cutoff=$cutoff)\"' >> submit-$f_no_e.sh;
					echo -e 'mv $f_no_e.phylip.dist ../' >> submit-$f_no_e.sh;
					echo -e 'cd ..' >> submit-$f_no_e.sh;
					echo -e 'tar -cvf - $f_no_e-clustering | gzip -c - > $f_no_e-results.tgz' >> submit-$f_no_e.sh;
					echo 'Submitting job';
					sbatch --cpus-per-task=$RES_C --job-name=auto_task-$f_no_e --mail-type=END --mail-user=$EMAIL submit-$f_no_e.sh;"
				;;
			esac
		;;
		rare)
			case $TOOL in
				fungene|rdp)
					#1 Write the commands and options text files
					SEQUENCE+="cd $OUT/auto_task-$NAME/;
					echo 'Writing job files';
					echo -e 'rarefaction' >> commands-$f_no_e.txt;"
					
					SEQUENCE+="echo $sent_gene >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME/$f_no_e-results >> options-$f_no_e.txt;
					echo $EMAIL >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME/status-$f_no_e.txt >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME/$f_no_e-results.tgz >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME/mail_message.txt >> options-$f_no_e.txt;
					"
					
					#2 Write the submission script
					SEQUENCE+="echo '#!/bin/bash' >> submit-$f_no_e.sh;
					echo '. /rc/tools/utils/dkinit' >> submit-$f_no_e.sh;
					echo 'use Python-EPD' >> submit-$f_no_e.sh;
					"
					
					SEQUENCE+="echo python $RES/programs/fungene_pipeline/fgp_wrapper.py options-$f_no_e.txt commands-$f_no_e.txt $f >> submit-$f_no_e.sh;"
					
					#3 submit the script to run
					SEQUENCE+="echo 'Submitting job';
					sbatch --cpus-per-task=$RES_C --job-name=auto_task-$f_no_e --mail-type=END --mail-user=$EMAIL submit-$f_no_e.sh;"
				;;
				mothur)
					SEQUENCE+="cd $OUT/auto_task-$NAME/;
					mkdir $f_no_e-rarefaction;
					echo 'Writing job files';
					echo '#!/bin/bash' >> submit-$f_no_e.sh;
					echo -e 'cd $f_no_e-rarefaction' >> submit-$f_no_e.sh;
					echo -e 'cp ../$f .' >> submit-$f_no_e.sh;
					echo -e '$RES/programs/mothur/mothur \"#rarefaction.single(list=$f, freq=2, processors=$RES_C)\"' >> submit-$f_no_e.sh;
					echo -e 'cd ..' >> submit-$f_no_e.sh;
					echo -e 'tar -cvf - $f_no_e-rarefaction | gzip -c - > $f_no_e-results.tgz' >> submit-$f_no_e.sh;
					echo 'Submitting job';
					sbatch --cpus-per-task=$RES_C --job-name=auto_task-$f_no_e --mail-type=END --mail-user=$EMAIL submit-$f_no_e.sh;"
				;;
			esac
		;;
		sc)
			case $TOOL in
				fungene|rdp)
					#1 Write the commands and options text files
					SEQUENCE+="cd $OUT/auto_task-$NAME/;
					echo 'Writing job files';
					echo -e 'shannon_chao' >> commands-$f_no_e.txt;"
					
					SEQUENCE+="echo $sent_gene >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME/$f_no_e-results >> options-$f_no_e.txt;
					echo $EMAIL >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME/status-$f_no_e.txt >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME/$f_no_e-results.tgz >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME/mail_message.txt >> options-$f_no_e.txt;
					"
					
					#2 Write the submission script
					SEQUENCE+="echo '#!/bin/bash' >> submit-$f_no_e.sh;
					echo '. /rc/tools/utils/dkinit' >> submit-$f_no_e.sh;
					echo 'use Python-EPD' >> submit-$f_no_e.sh;
					"
					
					SEQUENCE+="echo python $RES/programs/fungene_pipeline/fgp_wrapper.py options-$f_no_e.txt commands-$f_no_e.txt $f >> submit-$f_no_e.sh;"
					
					#3 submit the script to run
					SEQUENCE+="echo 'Submitting job';
					sbatch --cpus-per-task=$RES_C --job-name=auto_task-$f_no_e --mail-type=END --mail-user=$EMAIL submit-$f_no_e.sh;"
				;;
			esac
		;;
		blast)
			#1 create directories for cultured & uncultured results
			SEQUENCE+="echo Creating directories;
			cd $OUT/auto_task-$NAME/;
			mkdir $f_no_e-results;
			mkdir $f_no_e-results/cultured;
			mkdir $f_no_e-results/uncultured;
			mkdir $f_no_e-results/combined;
			"
			
			#2 run blast searches on both (blast_search.sh, filter.py, submit.sh)
			#3 combine results
			#4 compress results (cultured, uncultured, combined)
			SEQUENCE+="echo Writing submission script;
			echo '#!/bin/bash' >> submit-$f_no_e.sh;
			echo '. /rc/tools/utils/dkinit' >> submit-$f_no_e.sh;
			echo 'use BLAST' >> submit-$f_no_e.sh;
			echo 'export BLASTDB=$dbp' >> submit-$f_no_e.sh;
			echo '$blast -query $f -db $tdb -negative_gilist /projects/$ANUM/resources/job_files/uncultured_gis.txt -num_alignments $hits -outfmt \"6 qseqid sgi sstart send length\" -num_threads $RES_C > $f_no_e-results/cultured/blast_output.txt' >> submit-$f_no_e.sh;
			echo '$blast -query $f -db $tdb -num_alignments $hits -outfmt \"6 qseqid sgi sstart send length\" -num_threads $RES_C > $f_no_e-results/uncultured/blast_output.txt' >> submit-$f_no_e.sh;
			echo 'python $RES/scripts/blast_filter.py $f_no_e-results/cultured/blast_output.txt > $f_no_e-results/cultured/filtered_output.txt' >> submit-$f_no_e.sh;
			echo 'python $RES/scripts/blast_filter.py $f_no_e-results/uncultured/blast_output.txt > $f_no_e-results/uncultured/filtered_output.txt' >> submit-$f_no_e.sh;
			echo 'cat $f_no_e-results/cultured/filtered_output.txt $f_no_e-results/uncultured/filtered_output.txt >> $f_no_e-results/combined/combined_output.txt' >> submit-$f_no_e.sh;
			echo 'python $RES/scripts/blast_filter.py $f_no_e-results/combined/combined_output.txt > $f_no_e-results/combined/filtered_combined_output.txt' >> submit-$f_no_e.sh;
			echo '$RES/scripts/blast_get_fasta.sh $f_no_e-results/cultured/filtered_output.txt $f_no_e-results/cultured/cultured.fasta $tdb' >> submit-$f_no_e.sh;
			echo '$RES/scripts/blast_get_fasta.sh $f_no_e-results/uncultured/filtered_output.txt $f_no_e-results/uncultured/uncultured.fasta $tdb' >> submit-$f_no_e.sh;
			echo '$RES/scripts/blast_get_fasta.sh $f_no_e-results/combined/filtered_combined_output.txt $f_no_e-results/combined/combined.fasta $tdb' >> submit-$f_no_e.sh;
			echo 'tar -cvf - $f_no_e-results | gzip -c - > $f_no_e-results.tgz' >> submit-$f_no_e.sh;
			"
			
			SEQUENCE+="echo Submitting job;
			sbatch --cpus-per-task=$RES_C --job-name=auto_task-$f_no_e --mail-type=END --mail-user=$EMAIL submit-$f_no_e.sh;"
		;;
		pipeline)
			case $TOOL in
				fungene|rdp)
					#1 Write the commands and options text files
					SEQUENCE+="cd $OUT/auto_task-$NAME/;
					echo 'Writing job files';
					echo -e 'dereplicate\tunaligned' >> commands-$f_no_e.txt;
					echo -e 'align' >> commands-$f_no_e.txt;
					echo -e 'distance\t$cutoff\t0.01\t#=GC_RF' >> commands-$f_no_e.txt;
					echo -e 'cluster\tcomplete\t0.01' >> commands-$f_no_e.txt;
					echo -e 'rarefaction' >> commands-$f_no_e.txt;
					echo -e 'shannon_chao' >> commands-$f_no_e.txt
					echo -e 'explode_mapping\texpanded_mappings' >> commands-$f_no_e.txt;"
					
					SEQUENCE+="echo $sent_gene >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME/$f_no_e-results >> options-$f_no_e.txt;
					echo $EMAIL >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME/status-$f_no_e.txt >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME/$f_no_e-results.tgz >> options-$f_no_e.txt;
					echo $OUT/auto_task-$NAME/mail_message.txt >> options-$f_no_e.txt;
					"
					
					#2 Write the submission script
					SEQUENCE+="echo '#!/bin/bash' >> submit-$f_no_e.sh;
					echo '. /rc/tools/utils/dkinit' >> submit-$f_no_e.sh;
					echo 'use Python-EPD' >> submit-$f_no_e.sh;
					"
					
					SEQUENCE+="echo python $RES/programs/fungene_pipeline/fgp_wrapper.py options-$f_no_e.txt commands-$f_no_e.txt $f >> submit-$f_no_e.sh;"
					
					#3 submit the script to run
					SEQUENCE+="echo 'Submitting job';
					sbatch --cpus-per-task=$RES_C --job-name=auto_task-$f_no_e --mail-type=END --mail-user=$EMAIL submit-$f_no_e.sh;"
				;;
				combo)
					SEQUENCE+="cd $OUT/auto_task-$NAME/;
					mkdir $f_no_e-results;"
					SEQUENCE+="echo 'Writing submission file';
					echo '#!/bin/bash' > submit-$f_no_e.sh;
					echo 'mkdir $f_no_e-results/alignment' >> submit-$f_no_e.sh;
					echo '$RES/programs/muscle -in $f -out $f_no_e-results/alignment/$f_no_e-aligned.fasta' >> submit-$f_no_e.sh;
					"
					SEQUENCE+="cd $OUT/auto_task-$NAME/;
					mkdir $f_no_e-results/clustering;
					echo 'Writing job files';
					echo '#!/bin/bash' >> submit-$f_no_e.sh;
					echo -e 'cd $f_no_e-results/clustering' >> submit-$f_no_e.sh;
					echo -e 'cp ../alignment/$f_no_e-aligned.fasta .' >> submit-$f_no_e.sh;
					echo -e '$RES/programs/mothur/mothur \"#dist.seqs(fasta=$f_no_e-aligned.fasta, output=lt, processors=$RES_C)\"' >> submit-$f_no_e.sh;
					echo -e '$RES/programs/mothur/mothur \"#cluster.classic(phylip=$f_no_e-aligned.phylip.dist, cutoff=$cutoff)\"' >> submit-$f_no_e.sh;
					echo -e '$RES/programs/mothur/mothur \"#get.oturep(phylip=$f_no_e-aligned.phylip.dist, list=$f_no_e-aligned.phylip.an.list, cutoff=$cutoff)\"' >> submit-$f_no_e.sh;
					echo -e '$RES/programs/mothur/mothur \"#rarefaction.single(list=$f_no_e-aligned.phylip.an.list, freq=2, processors=$RES_C)\"' >> submit-$f_no_e.sh;
					echo -e 'mkdir ../rarefaction && mv $f_no_e-aligned.phylip.an.rarefaction ../rarefaction' >> submit-$f_no_e.sh;
					echo -e 'mv $f_no_e-aligned.phylip.dist ../../' >> submit-$f_no_e.sh;
					echo -e 'cd ../../' >> submit-$f_no_e.sh;
					echo -e 'tar -cvf - $f_no_e-results | gzip -c - > $f_no_e-results.tgz' >> submit-$f_no_e.sh;
					echo 'Submitting job';
					sbatch --cpus-per-task=$RES_C --job-name=auto_task-$f_no_e --mail-type=END --mail-user=$EMAIL submit-$f_no_e.sh;"
				;;
			esac
		;;
	esac
done

#Execute the sequence
ssh -t -t -i ~/.ssh/auto_task_key $ANUM@$LOGIN "$SEQUENCE"

echo "An email will be sent to $EMAIL when the job completes"
echo "To get the results run the script $TASK-retrieve.sh in this folder."
echo '#!/bin/bash' > retrieve.sh
echo "$AT_DIR/auto_task.sh get auto_task-$NAME" >> retrieve.sh
echo "tar xvf *.tgz" >> retrieve.sh
echo "rm -rf *.tgz" >> retrieve.sh
chmod +x retrieve.sh
