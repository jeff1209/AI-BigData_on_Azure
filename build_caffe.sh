#!/bin/bash
git clone https://github.com/yahoo/CaffeOnSpark.git --recursive
export CAFFE_ON_SPARK=$(pwd)/CaffeOnSpark

pushd ${CAFFE_ON_SPARK}/caffe-public/
cp Makefile.config.example Makefile.config
echo "INCLUDE_DIRS += ${JAVA_HOME}/include" >> Makefile.config
#Below configurations might need to be updated based on actual cases. For example, if you are using GPU, or using a different BLAS library, you may want to update those settings accordingly.
echo "CPU_ONLY := 1" >> Makefile.config
echo "BLAS := atlas" >> Makefile.config
echo "INCLUDE_DIRS += /usr/include/hdf5/serial/" >> Makefile.config
echo "LIBRARY_DIRS += /usr/lib/x86_64-linux-gnu/hdf5/serial/" >> Makefile.config
popd

#compile CaffeOnSpark
pushd ${CAFFE_ON_SPARK}
#always clean up the environment before building (especially when rebuiding), or there will be errors such as "failed to execute goal org.apache.maven.plugins:maven-antrun-plugin:1.7:run (proto) on project caffe-distri: An Ant BuildException has occured: exec returned: 2"
make clean 
#the build step usually takes 20~30 mins, since it has a lot maven dependencies
make build 
popd
export LD_LIBRARY_PATH=${CAFFE_ON_SPARK}/caffe-public/distribute/lib:${CAFFE_ON_SPARK}/caffe-distri/distribute/lib

hadoop fs -mkdir -p wasb:///projects/machine_learning/image_dataset

${CAFFE_ON_SPARK}/scripts/setup-mnist.sh
hadoop fs -put -f ${CAFFE_ON_SPARK}/data/mnist_*_lmdb wasb:///projects/machine_learning/image_dataset/

${CAFFE_ON_SPARK}/scripts/setup-cifar10.sh
hadoop fs -put -f ${CAFFE_ON_SPARK}/data/cifar10_*_lmdb wasb:///projects/machine_learning/image_dataset/

#put the already compiled CaffeOnSpark libraries to wasb storage, then read back to each node using script actions. This is because CaffeOnSpark requires all the nodes have the libarries
hadoop fs -mkdir -p /CaffeOnSpark/caffe-public/distribute/lib/
hadoop fs -mkdir -p /CaffeOnSpark/caffe-distri/distribute/lib/
hadoop fs -put CaffeOnSpark/caffe-distri/distribute/lib/* /CaffeOnSpark/caffe-distri/distribute/lib/
hadoop fs -put CaffeOnSpark/caffe-public/distribute/lib/* /CaffeOnSpark/caffe-public/distribute/lib/