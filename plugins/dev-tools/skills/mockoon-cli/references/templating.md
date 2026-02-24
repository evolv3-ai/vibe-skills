# Mockoon Templating Reference

Mockoon uses Handlebars-style templating with Faker.js integration.

---

## Faker.js Helpers

Generate realistic fake data in responses.

### Common Faker Methods

```handlebars
{{faker 'person.firstName'}}
{{faker 'person.lastName'}}
{{faker 'person.fullName'}}
{{faker 'internet.email'}}
{{faker 'internet.userName'}}
{{faker 'internet.url'}}
{{faker 'phone.number'}}
{{faker 'location.streetAddress'}}
{{faker 'location.city'}}
{{faker 'location.country'}}
{{faker 'company.name'}}
{{faker 'lorem.paragraph'}}
{{faker 'lorem.sentences' count=3}}
{{faker 'image.avatar'}}
{{faker 'image.url'}}
{{faker 'date.past'}}
{{faker 'date.future'}}
{{faker 'date.recent'}}
{{faker 'number.int' min=1 max=100}}
{{faker 'number.float' min=0 max=1 precision=0.01}}
{{faker 'string.uuid'}}
{{faker 'datatype.boolean'}}
```

### Arrays and Loops

```handlebars
{{#repeat 5}}
{
  "id": {{@index}},
  "name": "{{faker 'person.fullName'}}"
}{{#unless @last}},{{/unless}}
{{/repeat}}
```

---

## Request Data Helpers

### URL Parameters

```handlebars
{{urlParam 'id'}}
{{urlParam 'userId'}}
```

### Query Parameters

```handlebars
{{queryParam 'page'}}
{{queryParam 'limit' default='10'}}
{{queryParamRaw 'filters'}}
```

### Request Body

```handlebars
{{body}}
{{body 'user.name'}}
{{body 'items.0.id'}}
{{bodyRaw}}
```

### Headers

```handlebars
{{header 'Authorization'}}
{{header 'Content-Type'}}
```

### Cookies

```handlebars
{{cookie 'session_id'}}
```

---

## Environment Variables

```handlebars
{{getEnvVar 'API_KEY'}}
{{getEnvVar 'DATABASE_URL'}}
```

**Note**: Variables must be prefixed with `MOCKOON_` by default.

```bash
export MOCKOON_API_KEY=secret123
```

---

## Date/Time Helpers

```handlebars
{{now}}
{{now 'YYYY-MM-DD'}}
{{now 'HH:mm:ss'}}
{{dateTimeShift days=7}}
{{dateTimeShift months=-1 format='YYYY-MM-DD'}}
```

---

## String Helpers

```handlebars
{{#if (eq (urlParam 'type') 'admin')}}
  Admin content
{{else}}
  User content
{{/if}}

{{lowercase 'HELLO'}}
{{uppercase 'hello'}}
{{capitalize 'hello world'}}
{{trim '  hello  '}}
{{split 'a,b,c' ','}}
{{join (array 'a' 'b' 'c') '-'}}
```

---

## Math Helpers

```handlebars
{{add 5 3}}
{{subtract 10 4}}
{{multiply 3 7}}
{{divide 20 4}}
{{modulo 10 3}}
{{ceil 4.2}}
{{floor 4.8}}
{{round 4.5}}
```

---

## Conditional Helpers

```handlebars
{{#if (eq status 'active')}}
  Active user
{{/if}}

{{#if (gt count 10)}}
  More than 10
{{/if}}

{{#switch (urlParam 'type')}}
  {{#case 'user'}}User type{{/case}}
  {{#case 'admin'}}Admin type{{/case}}
  {{#default}}Unknown type{{/default}}
{{/switch}}
```

---

## Array Helpers

```handlebars
{{array 'item1' 'item2' 'item3'}}
{{oneOf (array 'red' 'green' 'blue')}}
{{someOf (array 'a' 'b' 'c' 'd') 2 3}}
{{#each (array 'a' 'b' 'c')}}
  {{this}}
{{/each}}
```

---

## Data Buckets

Reference shared data:

```handlebars
{{data 'bucketName'}}
{{data 'bucketName' 'property.path'}}
{{dataRaw 'bucketName'}}
```

---

## Example: Complete Response

```json
{
  "body": "{\n  \"user\": {\n    \"id\": \"{{faker 'string.uuid'}}\",\n    \"name\": \"{{faker 'person.fullName'}}\",\n    \"email\": \"{{faker 'internet.email'}}\",\n    \"role\": \"{{oneOf (array 'admin' 'user' 'guest')}}\",\n    \"createdAt\": \"{{now 'YYYY-MM-DDTHH:mm:ssZ'}}\"\n  },\n  \"requestId\": \"{{urlParam 'id'}}\",\n  \"query\": \"{{queryParam 'q'}}\"\n}"
}
```
