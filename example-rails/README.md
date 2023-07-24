
## Starwars Example

This is the simplest Ruby on Rails graphql application with Inigo middleware


<br/>

#### How to run:
1. Install dependencies
```bash
bundle install
```
2. Generate credentials
```bash
bin/rails credentials:edit
```
3. Get Inigo service token at [app.inigo.io](https://app.inigo.io)
4. Export env var to your current terminal session
```bash
export INIGO_SERVICE_TOKEN="{your_service_token}"
```
5. Start starwars app
```bash
bundle exec rails server
```
6. Send Graphql requests to [http://127.0.0.1:3000/query](http://127.0.0.1:8080/query)

<br/>
