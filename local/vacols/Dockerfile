FROM store/oracle/database-enterprise:12.2.0.1-slim

ENV DB_SID=BVAP

USER oracle

COPY dockerInitWithSchema.sh /home/oracle/setup/dockerInitWithSchema.sh
COPY loadSchema.sh /home/oracle/setup/loadSchema.sh

ADD setup_vacols.sql /ORCL/
ADD vacols_copy* /ORCL/

RUN mkdir -p /u01/app/oracle/oradata/BVAP

CMD ["bash", "-c", "/home/oracle/setup/dockerInitWithSchema.sh"]
