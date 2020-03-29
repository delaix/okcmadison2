class PagesController < ApplicationController
  def home
    @location = :Home
  end

  def about
    @location = :About
  end

  def classes
    cookies['has_visited_classes'] = true
    @location = :Classes
  end

  def blog
    @location = :Blog
  end
  
  def practical
    @location = 'Practical Karate'
  end
end
