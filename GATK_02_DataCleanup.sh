#!/bin/bash
# runs the complete Data Cleanup part of the GATK best practices pipeline
# Sort, Clean, MarkDuplicates, Add ReadGroups and IndelRealigner
# You'll need:
# 1. Alignment files in BAM format (for each line separately) with names formated as uniquename_otherinfo.bam
#    unique name shouldn't have any underscores in them, otherinfo added will be used for the readgroup [REQUIRED]
# 2. Reference genome in FASTA format (should be the same that was used for mapping) [REQUIRED]

module load picard_tools
module load java
module load samtools

FILE="$1"
REF="/home/arnstrm/arnstrm/20150413_Graham_SoybeanFST/01_DATA/B_REF/Gmax_275_v2.0.fa"
SAMPLE=$(echo ${FILE} |cut -d "_" -f 1)
UNIT=$(echo ${FILE} |cut -d "_" -f 2)

## Sorting BAM file
echo ${TMPDIR};
java -Xmx100G -jar /data003/GIF/software/packages/picard_tools/1.130/picard.jar SortSam \
  INPUT=${FILE} \
  OUTPUT=${TMPDIR}/${FILE%.*}_picsort.bam \
  SORT_ORDER=coordinate \
  MAX_RECORDS_IN_RAM=5000000 || {
  echo >&2 sorting failed for $FILE
  exit 1
}
cp ${TMPDIR}/${FILE%.*}_picsort.bam $PBS_O_WORKDIR/
## Cleaning Alignment file
java -Xmx100G -jar /data003/GIF/software/packages/picard_tools/1.130/picard.jar CleanSam \
  TMP_DIR=${TMPDIR} \
  INPUT=${TMPDIR}/${FILE%.*}_picsort.bam \
  OUTPUT=${TMPDIR}/${FILE%.*}_picsort_cleaned.bam \
  MAX_RECORDS_IN_RAM=5000000 || {
  echo >&2 cleaning failed for $FILE
  exit 1
}
cp ${TMPDIR}/${FILE%.*}_picsort_cleaned.bam $PBS_O_WORKDIR/
## Marking Duplicates
java -Xmx100G -jar /data003/GIF/software/packages/picard_tools/1.130/picard.jar MarkDuplicates \
  TMP_DIR=${TMPDIR} \
  INPUT=${TMPDIR}/${FILE%.*}_picsort_cleaned.bam \
  OUTPUT=${TMPDIR}/${FILE%.*}_dedup.bam \
  METRICS_FILE=${TMPDIR}/${FILE%.*}_metrics.txt \
  ASSUME_SORTED=true \
  REMOVE_DUPLICATES=true \
  MAX_RECORDS_IN_RAM=5000000 || {
  echo >&2 deduplicating failed for $FILE
  exit 1
}
cp ${TMPDIR}/${FILE%.*}_metrics.txt $PBS_O_WORKDIR/
cp ${TMPDIR}/${FILE%.*}_dedup.bam $PBS_O_WORKDIR/
## Adding RG info
java -Xmx100G -jar /data003/GIF/software/packages/picard_tools/1.130/picard.jar AddOrReplaceReadGroups \
  TMP_DIR=${TMPDIR} \
  INPUT=${TMPDIR}/${FILE%.*}_dedup.bam \
  OUTPUT=${TMPDIR}/${FILE%.*}_dedup_RG.bam \
  RGID=${SAMPLE} RGLB=SoyBean \
  RGPL=illumina \
  RGPU=${UNIT} \
  RGSM=${SAMPLE} \
  MAX_RECORDS_IN_RAM=5000000 \
  CREATE_INDEX=true || {
  echo >&2 RG adding failed for $FILE
  exit 1
}
cp ${TMPDIR}/${FILE%.*}_dedup_RG.bam* $PBS_O_WORKDIR/
## Indel Realigner: create intervals
java -Xmx60G -jar $GATK \
  -T RealignerTargetCreator \
  -R ${REF} \
  -I ${TMPDIR}/${FILE%.*}_dedup_RG.bam \
  -o ${TMPDIR}/${FILE%.*}_target_intervals.list || {
echo >&2 Target intervels list generation failed for $FILE
exit 1
}
cp ${TMPDIR}/${FILE%.*}_target_intervals.list $PBS_O_WORKDIR/
## Indel Realigner: write realignments
java -Xmx60G -jar $GATK \
  -T IndelRealigner \
  -R ${REF} \
  -I ${TMPDIR}/${FILE%.*}_dedup_RG.bam \
  -targetIntervals ${TMPDIR}/${FILE%.*}_target_intervals.list \
  -o ${TMPDIR}/${FILE%.*}_realigned.bam || {
echo >&2 Indel realignment failed for $FILE
exit 1
}
cp ${TMPDIR}/${FILE%.*}_realigned.bam $PBS_O_WORKDIR/
echo "All done!"