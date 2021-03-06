#!/bin/bash

# performs phasing and imputation of a VCF file
# using Beagle
# run the script as :
# sh beagle_PhaseImpute_VCF.sh input.vcf

INPUT="$1"
OUTPUT=$(basename ${INPUT%.*})

awk '(/#/ || ($4!~"," && $5!~"," && length($4)==1 && length($5)==1))' ${INPUT} > ${OUTPUT}_biAllelic.vcf
module use /shared/software/GIF/modules
#module load java/1.7.0_76
module load java/1.8.0_25-b17
module load beagle


java -Xmx100g -jar ${beagle} \
 nthreads=16 \
 window=50000 \
 ibd=true \
 gtgl=${OUTPUT}_biAllelic.vcf \
 out=${OUTPUT}_PhasedImputed

