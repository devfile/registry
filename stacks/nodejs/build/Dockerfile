# Install the app dependencies in a full Node docker image
FROM registry.access.redhat.com/ubi8/nodejs-12:1-45

COPY . /project/

# Support arbitrary user ids
RUN chgrp -R 0 /project && \
    chmod -R g=u /project

# Removing node_modules
RUN rm -rf /project/node_modules

# Install user-app dependencies
WORKDIR /project
RUN npm install --production

CMD ["npm", "start"]