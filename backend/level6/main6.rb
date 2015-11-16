require "json"
require 'pry'

# get the Json object from data.json and prepare output hash + new hash for rental modifications
file = File.read('data.json')
data = JSON.parse(file)
output = {"rentals" => []}
output_modif = {"rental_modifications" => []}

###################
# Methods to: find a car by id, get number of rental days, discounted cost per day
# now adding Commissions
# getting deductible - passing it on rental object to be more like class method on a DB object
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

def calc_commissions full_price, n_days
  commission_amount = 0.3 * full_price
  insurance_fee = 0.5 * commission_amount
  assistance_fee = 100*n_days
  drivy_fee = [commission_amount - insurance_fee - assistance_fee, 0].max

  commission = {
    insurance_fee: insurance_fee,
    assistance_fee: assistance_fee,
    drivy_fee: drivy_fee
  }
end

def get_deductible rental 
  return 0 if !rental['deductible_reduction']

  400 * number_days(rental)
end

###################
# Method the output for the original amounts
# Extract all ops in a method so I can use with the modified rental
###################

def get_rental_computations data, rental
  car = find_car_by_id(data, rental['car_id'])

  # time component accounting for discout
  n_days = number_days(rental)
  ppday = car['price_per_day']
  time_cost = decreased_pricing(ppday, n_days)

  # distance componebt: km * cost per km
  distance_cost = rental['distance'] * car['price_per_km']

  # Prepare objects with all info from the rental
  full_price = time_cost + distance_cost
  commission = calc_commissions(full_price, n_days)
  deductible_reduction = get_deductible(rental)

  data_rental = {
    'driver' => full_price + deductible_reduction,
    'owner' => full_price - commission.values.inject(:+),
    'insurance' => commission[:insurance_fee],
    'assistance' => commission[:assistance_fee],
    'drivy' => commission[:drivy_fee] + deductible_reduction
  }
end

def build_payment_per_actor data_rental, status
  # understand if we should write debit or credit thanks to the status passed
  # use aboslute values as debit/credit are there
  driver = "debit"
  rest = "credit"
  if (status === 'change') 
    driver = "credit"
    rest = "debit"
  end
  return [
    {"who" => "driver", "type" => driver, "amount" => data_rental['driver'].abs },
    {"who" => "owner", "type" => rest, "amount" => data_rental['owner'].abs },
    {"who" => "insurance", "type" => rest, "amount" => data_rental['insurance'].abs },
    {"who" => "assistance", "type" => rest, "amount" => data_rental['assistance'].abs },
    {"who" => "drivy", "type" => rest, "amount" => data_rental['drivy'].abs }
  ]
end

###################
# iterate through the array of rental IDs to extract all infos
###################

data["rentals"].each do |rental|
  # Extract all ops in a method so I can use with the modified rental
  data_rental = get_rental_computations(data, rental)
  # add results to the array of rentals
  output['rentals'] << {
    "id" => rental['id'],
    "actions" => build_payment_per_actor(data_rental, 'new')
  }
end

###################
# Now take care of MODIFICATIONS
# we will recompute all numbers for the modified object then calculate the deltas
###################


data["rental_modifications"].each do |rental_modif|
  # grab the original rental object 
  # detect so we stop at first instance
  rental_object = data['rentals'].detect {|rental| rental['id'] === rental_modif['rental_id']}
  # keep a copy of all the info on who pays who
  data_rental_init = get_rental_computations(data, rental_object)

  #  update object with the modifications
  rental_object['start_date'] = rental_modif['start_date'] if rental_modif['start_date']
  rental_object['end_date'] = rental_modif['end_date'] if rental_modif['end_date']
  rental_object['distance'] = rental_modif['distance'] if rental_modif['distance']
  # recalculate all data
  data_rental_modif = get_rental_computations(data, rental_object)

  # we can now compare original with modified numbers and calculate the deltas
  data_rental_deltas = {
    'driver' => data_rental_modif['driver'] - data_rental_init['driver'],
    'owner' => data_rental_modif['owner'] - data_rental_init['owner'],
    'insurance' => data_rental_modif['insurance'] - data_rental_init['insurance'],
    'assistance' => data_rental_modif['assistance'] - data_rental_init['assistance'],
    'drivy' => data_rental_modif['drivy'] - data_rental_init['drivy']
  }

  # rebuild the summary of actions
  # if delta for driver is negative then driver becomes in credit and everyone else in debit
  status = data_rental_deltas['driver'] > 0 ? 'new' : 'change'
  actions_modif_w_deltas = build_payment_per_actor(data_rental_deltas, status)

  # add results to the array of rental modifs
  output_modif['rental_modifications'] << {
    "id" => rental_modif['id'],
    "rental_id" => rental_modif['rental_id'],
    "actions" => actions_modif_w_deltas
  }
end


# create the output file - using a different name so you can compare with the expected ouput
File.new('output_modif.json', 'w+').write(JSON.pretty_generate output_modif)
