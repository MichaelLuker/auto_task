#!/bin/bash

lpl=false

function pause()
{
	if [[ $lpl == true ]]; then read t; fi
}

#Arguments to send for local, 1 file runs of auto_task
arglist=(
''
'help'
'help align'
'help cluster'
'help abund'
'help rare'
'help sc'
'help shannon_chao'
'help subsample'
'help rep'
'help blast'
'help tree'
'help pcoa'
'help pipeline'
'help get'
'help chop'
'help muscle'
'help muscle-mp'
'help rdp'
'help fungene'
'align'
'align muscle'
'align muscle-mp'
'align rdp'
'align fungene'
'align muscle test.fasta'
'align muscle-mp test.fasta'
'align rdp test.fasta'
'align fungene test.fasta'
'cluster'
'cluster mothur'
'cluster rdp'
'cluster fungene'
'cluster mothur test.fasta'
'cluster rdp test.fasta'
'cluster fungene test.fasta'
)

echo "Line by line calling: $lpl"
echo
echo "=============================================================================="
for i in "${arglist[@]}"; do
	
	echo "Called with: $i"
	./auto_task.sh $i
	echo "=============================================================================="
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "=============================================================================="
	pause
done
