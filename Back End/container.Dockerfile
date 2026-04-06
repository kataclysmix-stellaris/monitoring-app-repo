FROM python
WORKDIR /app
COPY package*.python ./
RUN npm install
COPY . data_string.json.
ENV PORT=9000
EXPOSE 9000
CMD ["npm","start"]