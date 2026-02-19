# Base Node.js image
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy entire project
COPY . .

# Build Strapi admin panel
RUN npm run build

# Start Strapi server in production mode
CMD ["npm","run","start"]

