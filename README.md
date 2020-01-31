# Sample code to simulate a paginated endpoint

This is just a simple demo to showcase fixes to a very simple excercise where we have a class that pulls collection in a paginated way from an external API.

Main idea is that we initialize the class with the following parameters:

 - offset
 - limit
 - page_size
 - filters

**offset** is essentially the position where we want to start pulling the records in regards of the current collection available

**limit** the API could return hundreds of records but we may want to limit the results to a certain amount, this would be the actual paginated records, so to say

**page_size** this one is tricky because of the name _(would be better called cursor?)_ but essentially works as a way to enhance performance by pulling data in batches so no need to pull say 100 records if we are going to iterate only on the first 10 initially

**filters** could be anything that helps to filter the data from the API, like a customer ID, a branch or store ID etc.

## Notes

### Using parameters in an object instead on the initializer

Many contexts in specs due to parameters of behavior being used in initializer of class. 

In the same topic as above, we could use a refactor and have a `fetch` method or something similar that takes the parameters so we don't have to instantiate a new object each time, but this depends greatly on the context where this `OrderCollection` class would be used

Speaking of parameters, in cases like this, I like to use keyword parameters better because they are more readable:

compare this:

```ruby
OrderCollection.new(5, 50, 10)
```

to this:

```ruby
OrderCollection.new(offset: 5, limit: 50, page_size: 10)
```

We can always read the documentation or take a look at the signature of methods but it just makes things easier. There are cases where the method name may be explicit on what it does where I think keyword arguments are overkill:

```ruby
Order.process(123)
```

It's more straightforward and we can tell that this probably is going to process an order with that ID.

### Error handling

Since we know that the `APIClient` call can fail, it is better IMO to just let the errors continue up in the stack and act accordingly, this, again, depends on the context, if we were using this class so simply pull data to present in some view or to an end-user then half-processed requests don't seem right, however, if we were using this class within a background process (say, processing order payments) then it makes sense that we may want to do partial processing and retry.

### Concurrency / Data integrity

Concurrency and consistency are issues that may happen due to many factors, like records being deleted, that could cause for instance the following scenario:

Fetching from the following records with a page size of 4:

```
1, 2, 3, 4, 5, 6, 7, 8
```

We've got the following:

```
1, 2, 3, 4
```

However, in the next iteration, that happened _some time_ after we pulled the first page, `2` and `3` records were removed, and some others added:

```
1, 3, 5, 6, 7, 8, 9, 10
```

So if we simply used a _limit/offset_ approach then the next following 4 records would start in the 7th element so we already lost track of `5` and `6`. The best way to solve this problem is to simply keep track of the last ID of the record and make it the actual offset instead of just using integers based on autonumeric increments.

What's also important is the ordering or the data, is it being ordered by creation date or modification date, or maybe its not even being ordered. So, again, all these are factors to the possible solution.

In fact in some databases, especially nosql, like DynamoDB, you do need to keep track of the last element ID in order to retrieve the next set since there is no autoincrement concept.

Extra filters are also important, like cases where we use _soft delete_ and that is probably most of the time because we rarely want to completely remove records, especially those that have related data, so to keep integrity.

