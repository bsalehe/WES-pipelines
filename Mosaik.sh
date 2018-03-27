read -p " enter your Reference:" Re1
read -p " enter the Read 1:" r1
read -p " enter the Read 2:" r2
#indexing
MosaikBuild -fr "$Re1"-oa "$Re1".dat
#Alignment
MosaikBuild -q Data/"$r1" -q2 Data/"$r2" -st illumina -out output/"$r1"/"$r1"_Mosaik.mkb
#coversion kindly procide the .annpe and annse file from the mosaik installation director
MosaikAligner -in output/"$r1"/"$r1"_Mosaik.mkb -out output/"$r1"/"$r1".MOSAIK -p 10 -ia "$Re1".dat -j "$Re1" -annpe 2.1.26.pe.100.0065.ann -annse 2.1.26.se.100.005.ann
#Sort_Bam
java -Xmx10g -jar Tools/picard-tools-1.141/picard.jar SortSam VALIDATION_STRINGENCY=SILENT I=output/"$r1"/"$r1".MOSAIK.bam O=output/"$r1"/"$r1"_Sort_mosaik.bam SORT_ORDER=coordinate
#Pcr_Duplicates
java -Xmx10g -jar Tools/picard-tools-1.141/picard.jar MarkDuplicates VALIDATION_STRINGENCY=SILENT I=output/"$r1"/"$r1"_Sort_mosaik.bam O=output/"$r1"/"$r1"_PCR_mosaik.bam REMOVE_DUPLICATES=true M=output/"$r1"/"$r1"_pcr_mosaik.metrics
#ID_Addition
java -Xmx10g -jar Tools/picard-tools-1.141/picard.jar AddOrReplaceReadGroups VALIDATION_STRINGENCY=SILENT I=output/"$r1"/"$r1"_PCR_mosaik.bam O=output/"$r1"/"$r1"_RG_mosaik.bam SO=coordinate RGID=SRR"$r1" RGLB=SRR"$r1" RGPL=illumina RGPU=SRR"$r1" RGSM=SRR"$r1" CREATE_INDEX=true
#Realignmnet_Metrix
java -Xmx10g -jar Tools/GenomeAnalysisTK.jar -T RealignerTargetCreator -R "$Re1" -I output/"$r1"/"$r1"_RG_mosaik.bam -o output/"$r1"/"$r1"_Realignement_mosaik.list --filter_mismatching_base_and_quals
#Realignment
java -Xmx10g -jar Tools/GenomeAnalysisTK.jar -T IndelRealigner -R "$Re1" -targetIntervals output/"$r1"/"$r1"_Realignement.list -I output/"$r1"/"$r1"_RG_mosaik.bam -o output/"$r1"/"$r1"_Realignment_mosaik.bam --filter_mismatching_base_and_quals
#baseQuality_Check
java -jar Tools/GenomeAnalysisTK.jar -T BaseRecalibrator -R "$Re1" -I output/"$r1"/"$r1"_Realignment_mosaik.bam -o output/"$r1"/"$r1"_Realignment_mosaik_data.table
#quality
java -jar Tools/GenomeAnalysisTK.jar -T PrintReads -R "$Re1" -I output/"$r1"/"$r1"_Realignment_mosaik.bam -BQSR output/"$r1"/"$r1"_Realignment_mosaik_data.table -o output/"$r1"/"$r1"_mosaik_recal.bam
#Variant_Calling-GATK
java -Xmx10g -jar Tools/GenomeAnalysisTK.jar -T HaplotypeCaller -R "$Re1" -I output/"$r1"/"$r1"_mosaik_recal.bam -o output/"$r1"/mosaik_GATK_"$r1".vcf
#Variant_Calling-Samtools
samtools mpileup -go output/"$r1"/mosaik_samtools_"$r1".bcf -f "$Re1" output/"$r1"/"$r1"_mosaik_recal.bam
#bcf_to_VCF_converstion
bcftools call -vmO z -o output/"$r1"/mosaik_samtools_"$r1".vcf output/"$r1"/mosaik_samtools_"$r1".bcf
#Variant_Calling-Free_Bayes
freebayes -f -f "$Re1" -v output/"$r1"/mosaik_Freebayes_"$r1".vcf output/"$r1"/"$r1"_mosaik_recal.bam
#Variant_Calling-Deep_Variant
MODEL=DeepVariant-inception_v3-0.4.0+cl-174375304.data-wgs_standard/model.ckpt
OUTPUT_DIR="$r1"_mosaik
mkdir -p "${OUTPUT_DIR}"
LOGDIR=./mosaik_logs
N_SHARDS=10
mkdir -p "${LOGDIR}"
time seq 0 $((N_SHARDS-1)) | parallel --eta --halt 2 --joblog "${LOGDIR}/log" --res "${LOGDIR}" python bin/make_examples.zip  --mode calling --ref "$Re1" --reads output/"$r1"/"$r1"_mosaik_recal.bam --examples "${OUTPUT_DIR}/examples.tfrecord@${N_SHARDS}.gz" --task {}
python bin/call_variants.zip --outfile output/"$r1"/mosaik_Deep_"$r1".gz --examples "${OUTPUT_DIR}/examples.tfrecord@${N_SHARDS}.gz" --checkpoint "${MODEL}"
python bin/postprocess_variants.zip --ref "$Re1" --infile output/"$r1"/mosaik_Deep_"$r1".gz --outfile output/"$r1"/mosaik_Deep_"$r1".vcf
#variant_Sepration_Indel_SNV
vcftools --vcf output/"$r1"/mosaik_GATK_"$r1".vcf --remove-indels --recode --recode-INFO-all --out output/"$r1"/mosaik_GATK_SNP_"$r1".vcf
vcftools --vcf output/"$r1"/mosaik_samtools_"$r1".vcf --remove-indels --recode --recode-INFO-all --out output/"$r1"/mosaik_Samtools_SNP_"$r1".vcf
vcftools --vcf output/"$r1"/mosaik_Freebayes_"$r1".vcf --remove-indels --recode --recode-INFO-all --out output/"$r1"/mosaik_FreeBayes_SNP_"$r1".vcf
vcftools --vcf output/"$r1"/mosaik_Deep_"$r1".vcf --remove-indels --recode --recode-INFO-all --out output/"$r1"/mosaik_Deep_SNP_"$r1".vcf
vcftools --vcf output/"$r1"/mosaik_GATK_"$r1".vcf --keep-only-indels  --recode --recode-INFO-all --out output/"$r1"/mosaik_GATK_Indels_"$r1".vcf
vcftools --vcf output/"$r1"/mosaik_samtools_"$r1".vcf --keep-only-indels  --recode --recode-INFO-all --out output/"$r1"/mosaik_Samtools_Indels_"$r1".vcf
vcftools --vcf output/"$r1"/mosaik_Freebayes_"$r1".vcf --keep-only-indels  --recode --recode-INFO-all --out output/"$r1"/mosaik_FreeBayes_Indels_"$r1".vcf
vcftools --vcf output/"$r1"/mosaik_Deep_"$r1".vcf --keep-only-indels  --recode --recode-INFO-all --out output/"$r1"/mosaik_Deep_Indels_"$r1".vcf
