# The Journal of Open Source Software

[![Build Status](https://github.com/openjournals/joss/actions/workflows/tests.yml/badge.svg)](https://github.com/openjournals/joss/actions/workflows/tests.yml)
[![Powered by NumFOCUS](https://img.shields.io/badge/powered%20by-NumFOCUS-orange.svg?style=flat&colorA=E1523D&colorB=007D8A)](http://numfocus.org)
[![Donate to JOSS](https://img.shields.io/badge/Donate-to%20JOSS-brightgreen.svg)](https://numfocus.org/donate-to-joss)

The [Journal of Open Source Software](https://joss.theoj.org) (JOSS) is a developer friendly journal for research software packages.

### What exactly do you mean by 'journal'

The Journal of Open Source Software (JOSS) is an academic journal with a formal peer review process that is designed to _improve the quality of the software submitted_. Upon acceptance into JOSS, a CrossRef DOI is minted and we list your paper on the JOSS website.

### Don't we have enough journals already?

Perhaps, and in a perfect world we'd rather papers about software weren't necessary but we recognize that for most researchers, papers and not software are the currency of academic research and that citations are required for a good career.

We built this journal because we believe that after you've done the hard work of writing great software, it shouldn't take weeks and months to write a paper<sup>1</sup> about your work.

### You said developer friendly, what do you mean?

We have a simple submission workflow and extensive documentation to help you prepare your submission. If your software is already well documented then paper preparation should take no more than an hour.

<sup>1</sup> After all, this is just advertising.

## The site

The JOSS submission tool is hosted at https://joss.theoj.org

## JOSS Reviews

If you're looking for the JOSS reviews repository head over here: https://github.com/openjournals/joss-reviews/issues

## Code of Conduct

In order to have a more open and welcoming community, JOSS adheres to a code of conduct adapted from the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

Please adhere to this code of conduct in any interactions you have in the JOSS community. It is strictly enforced on all official JOSS repositories, the JOSS website, and resources. If you encounter someone violating these terms, please let the Editor-in-Chief ([@arfon](https://github.com/arfon)) or someone on the [editorial board](https://joss.theoj.org/about#editorial_board) know and we will address it as soon as possible.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## ⚙️ Development

[LiveReload](https://github.com/guard/guard-livereload) enables the browser to automatically refresh on change during development.

1. Download the [LiveReload Chrome plugin](https://chrome.google.com/webstore/detail/livereload/jnihajbhpnppcggbcgedagnkighmdlei/)
2. Run `bundle exec guard`


NeuroLibre App Documentation	


## Your entrypoint to a Ruby on Rails app: Views (`app/views`)

The ".erb" extension stands for Embedded Ruby, which means that these files can contain dynamic content and logic that is executed on the server-side.

When a user makes a request to a Rails application, the controller determines which view to render based on the requested URL and any data passed to it. The view is then rendered using the data passed from the controller and any dynamic content and logic contained in the HTML.erb file.

These HTML.erb files are an important part of the Ruby on Rails framework and are used extensively to create dynamic, interactive web applications.

For example, when a “published” article is requested by a reader, the controller selects `_show_published_nl.html.erb` template to render the respective webpage (that shows the PDF and other information). 

#### Partial files

In a Ruby on Rails application, an HTML.erb file name that starts with an underscore (e.g. _partial.html.erb) is called a partial file. Partial files are reusable templates that can be included in other views to promote modularity and reduce duplication of code.

These partial files are then included in the main view(s) using the <%= render %> method.

NeuroLibre partial files have an `_nl` suffix in order to minimize merge conflicts with upstream (the main joss repository) changes. 


#### Accessing instance variables 

Instance variables are defined by the `controllers` (e.g. `app/controllers/papers_controller.rb`). For example,  we can access the @paper variable in the view using <%= @paper.book_exec_url %>. In this example, @paper is an instance variable that contains a Paper object and we are accessing the `book_exec_url` attribute of that object.

It's worth noting that instance variables defined in the controller are not automatically available in the view. They must be explicitly defined and assigned a value in the controller action before they can be accessed in the view (e.g., see `app/controllers/dispatch_controller.rb` L108).

In a Ruby on Rails application, instance variables defined in the controller are often associated with models in the application. Therefore, at this point, you may want to check what models are in the following section before moving on with this section. 

For example, @paper.clean_data_doi is not an attribute that is associated with the database schema (a papers table has `repository_doi`, `data_doi`, `docker_doi` etc. but not a `clean_data_doi`). This `clean_data_doi` is a function defined in the `app/models/paper.rb` that returns a string after dealing performing some string manipulation. 

#### Helpers (`app/helpers`)

If you see a function popped out of nowhere in an html.erb. view (e.g. `pretty_book_link`), that’s most likely a `helper`. 

The helpers are modules that provide utility methods that can be used in views and controllers (not in the models). Helpers are used to encapsulate functionality that is shared across different parts of the application, and to keep the code organized and maintainable.

#### Models (`app/models`)

A model defines the relationships between data entities and interacts with the database to retrieve, manipulate, and persist data. 

In the context of Ruby on Rails, a model is typically implemented as a class that inherits from the ActiveRecord::Base class (e.g., `app/models/paper.rb`. The model class is responsible for defining the attributes and associations of the entity it represents, as well as any application (well, actually the business) logic or validations that apply to that entity.

> Business logic: Rules, processes, and workflows that define how the application behaves with respect to the real-world problem (i.e. reviewing and publishing reproducible preprints) of question.  

A model class can contain function definitions, which are methods that define behavior specific to the model. These methods can be used to encapsulate business logic and other functionality that operates on the data stored in the model (e.g., `repository_doi_with_url`).

*** 

Starting from the `app/views` context, we have seen critical abstractions in a Ruby on Rails application. This should give you a better idea about how to manage new additions or changes you’d like to make to rendering certain pages. See the following section on handling the data. 

### Tests (`spec/)

RSpec is a popular testing framework used in Ruby on Rails that allows you to write tests for your application's models, controllers, and other code. RSpec provides a DSL (Domain-Specific Language) that allows you to write tests that are expressive and easy to read.

RSpec tests are typically located in the "spec" directory of your Rails application. Within the "spec" directory, you will typically find subdirectories for each type of code that you are testing, such as "models", "controllers", or "helpers". Within each of these directories, you can create spec files that contain your tests.