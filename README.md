__Don't use me yet - soon!__

Wouldn't it be awesome if you could split your application in half a provide a beautiful API that would not only be used by the controller half of our application, but also be a clean, standardized public facing API?

    # id, title, created_at
    class Article < ActiveRecord::Base
	    include FlexibleApi
    end

Starting up a the sinatra server using `thin start` or `shotgun` (or whatever container you prefer), you can visit:

    http://localhost:9393/articles  # a beautiful list of your articles is JSON format
    http://localhost:9393/articles/:id  # details on an individual article in JSON format

If you'd rather have the data in a different format, just add a flag like:

    http://localhost:9393/articles?format=xml

(you can also use .xml or an Accept header)

---

## Request Levels

You don't always want to expose the same flat record in every case obviously, and for that we have request levels:

    # id, title, created_at
    class Article < ActiveRecord::Base
      include FlexibleApi
      define_request_level :single do  
        fields :title, :created_at
      end
    end

Now that you've defined that request level you can get all of the details about the article by visiting: 

    http://localhost:9393/articles

Or get the details in the format of that request level by visiting:

    http://localhost:9393/articles?level=single

If you want a certain request level to be the default (a common case), you can do so with `default_request_level :single`

---

## Eating other levels

You can build levels as combinations of other levels like so:

    define_request_level :name_only do
      fields :name
    end

    define_request_level :single do
      eat_level :name_only
      fields :id
    end

---

## And...

You get free arguments for `?limit` and `?offset` for that pagination you have to do

## Request Formats

You can use Accept headers, `.xxx`, or `?format=` to specify any of the following three:

* `json`
* `xml`
* `jsonp` with an optional `callback=`

---

## Notations

You can also add notations to request levels, like so:

    # id, title, created_at
    class Article < ActiveRecord::Base
      include FlexibleApi
      define_request_level :single do
        fields :title
        notation(:reverse_title) { title.reverse }
      end
    end

    a = Article.create(:title => 'something')
    { :title => 'something', :reverse_title => 'gnihtemos' }

If your notations have requirements that aren't part of your #fields, you can add requirements.  They'll be selected, but not returned on the call:

    class Article < ActiveRecord::Base
      include FlexibleApi
      define_request_level :single do
        fields :id
        notation(:reverse_title) { title.reverse }
        requires :title
      end
    end

    a = Article.create(:title => 'something')
    { :id => id, :reverse_title => 'gnihtemos' }

You can also (and should) specify requirements inline when possible:

    define_request_level :single do
      add_notation(:reverse_title, :requires => [:title]) { title.reverse }
    end

---

## Includes

This is where is gets interesting.  Request levels can contain includes to associations on the class.

    # id, title, created_at
    class Article < ActiveRecord::Base
      has_many :comments
      include FlexibleApi
      define_request_level :nested do
        includes :comments
      end
    end

    # id, comment, created_at
    class Comment < ActiveRecord::Base
      belongs_to :article
      include FlexibleApi
    end

So now when you visit `http://localhost:9393/articles/:id`, you will see a nested association which contains all of the comments.  You can even add a parameter to include like `:request_level => :inner` to use a non-default request_level on Comment in the nesting.  BeautifulApi will take care of all of the preloading and selecting.  You just sit back and enjoy.

Every result will also have an :associations member of the hash, saying what calls can be made from that object.

---

## Advanced includes

Specify a request level to use for the association

    define_request_level :nested do
      include :comments, :request_level => :inner
    end

---

## Scoping

For convenience, on any of the default-generated URLs you can make calls like:

    http://localhost:9393/articles:published:another_filter

to apply filters to your base calls easily

---

## Using the reference

    Go to your root URL for a free reference to your API
