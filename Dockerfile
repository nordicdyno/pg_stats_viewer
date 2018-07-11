FROM perl:5.26
LABEL maintainer="Alexander Orlovsky <nordicdyno@gmail.com>"
# add cpanm dependencies
RUN cpanm --verbose --notest Term::ReadKey && rm -rf ~/.cpanm
RUN cpanm --verbose App::cpm && rm -rf ~/.cpanm

# install dependencies and code
ADD cpanfile /root/cpanfile
RUN cpm install --test --verbose -g && rm -rf ~/.cpanm
ADD . /app
WORKDIR /app
CMD command starman --port 9000
