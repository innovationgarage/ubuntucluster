FROM ubuntu:16.04

RUN apt-get update
RUN apt-get install -y openssh-server
RUN apt-get install -y parallel
RUN apt-get install -y build-essential
RUN apt-get install -y language-pack-en
RUN apt install nano mg

RUN mkdir /var/run/sshd
#RUN echo 'root:password' | chpasswd
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

RUN echo "export LC_ALL=en_US.UTF-8" >> /root/.bashrc
RUN echo "source /root/.clusterenv" >> /root/.bashrc

ADD server.sh /server.sh

EXPOSE 22
CMD ["/server.sh"]
