#Warning : never use this in production
#add the base image
FROM lsucrc/crcbase
USER root
WORKDIR /root
RUN mkdir /var/run/sshd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Unlock non-password USER to enable SSH login
RUN passwd -u root

RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key

# SSH login fix. Otherwise user is kicked off after login
RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config
RUN sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config

RUN mkdir /root/.ssh
ADD ssh/config /root/.ssh/config
ADD ssh/id_rsa /root/.ssh/id_rsa
ADD ssh/id_rsa.pub /root/.ssh/id_rsa.pub
ADD ssh/id_rsa.pub /root/.ssh/authorized_keys
ADD helloworld.c /root/helloworld.c

RUN echo "export PATH=$PATH:$HOME/bin:/usr/lib64/openmpi/bin" >> /root/.bash_profile
RUN echo "export LD_LIBRARY_PATH=/usr/lib64/openmpi/lib:$LD_LIBRARY_PATH" >> /root/.bash_profile
RUN source /root/.bash_profile
RUN mpicc -o helloworld /root/helloworld.c

RUN chmod -R 600 /root/.ssh/*

ENV PATH=$PATH:/usr/lib64/openmpi/bin \
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib64/openmpi/lib \
    LD_PRELOAD=/usr/lib64/openmpi/lib/libmpi.so
RUN ln -s  /usr/lib64/openmpi/bin/orted /usr/bin


# complie funwave-tvd 
WORKDIR /model
RUN wget --secure-protocol=auto https://www1.udel.edu/kirby/programs/funwave/funwave-version2.1.zip && \
    unzip funwave-version2.1.zip

WORKDIR funwave-version2.1/src

# remove -C option to avoid generating C comments
RUN sed -i 's/DEF_FLAGS     = -P -C -traditional/            DEF_FLAGS     = -P -traditional/' Makefile
RUN sed -i '/^\smv/d' Makefile

# compile funwave
RUN make 

# set up enviroment variable of funwave
RUN echo "PATH=$PATH:/model/funwave-version2.1/src" >> /root/.bash_profile
RUN source /root/.bash_profile
RUN chmod +rx /model/funwave-version2.1/src/mytvd

EXPOSE 225
CMD ["/usr/sbin/sshd", "-D"]
