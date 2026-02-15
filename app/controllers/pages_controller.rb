class PagesController < ApplicationController
  def home
    @location = :Home
  end

  def about
    @location = :About
  end

  def classes
    @location = :Classes
  end
  
  def practical
    @location = 'Practical Karate'
  end

  def social
    @location = :Social
  end
end
