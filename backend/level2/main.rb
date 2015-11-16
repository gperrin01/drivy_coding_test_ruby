require "json"
require 'pry'

# get the Json object from data.json and prepare output hash
file = File.read('data.json')
data = JSON.parse(file)
output = {"rentals" => []}

###################
# Methods to: find a car by id, get number of rental days
# now adding re-calculation of the cost per day
###################

def find_car_by_id data, id
  data['cars'].detect{|car| car['id'] == id}
end

def number_days rental
  ( Date.parse(rental['end_date']) - Date.parse(rental['start_date']) ).to_i + 1
end

def decreased_pricing init_ppday, days_renting 
  price_array = [init_ppday]
  # days 2-3-4: 3 days at 10% discount
  price_array << 0.9*init_ppday * [3, days_renting - 1].min
  # days 5--10: 6 days at 30% discount
  price_array << 0.7*init_ppday * [6, days_renting - 4].min if days_renting > 4
  # all days above 10 at 50% discount
  price_array << 0.5*init_ppday * (days_renting - 10) if days_renting > 10

  discounted_total = price_array.inject(:+)
end

###################
# Getting the output
###################

# iterate through the array of rental IDs to calculate their price
data["rentals"].each do |rental|
  car = find_car_by_id(data, rental['car_id'])

  # time component accounting for discout
  n_days = number_days(rental)
  ppday = car['price_per_day']
  time_cost = decreased_pricing(ppday, n_days)

  # distance componebt: km * cost per km
  distance_cost = rental['distance'] * car['price_per_km']

  # update this rental in the output object
  output['rentals'] << {"id" => rental['id'], 'price' => time_cost + distance_cost}
end

# create the output file - using a different name so you can compare with the expected ouput
File.new('output2.json', 'w+').write(JSON.pretty_generate output)
