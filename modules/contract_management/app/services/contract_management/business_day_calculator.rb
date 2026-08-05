# frozen_string_literal: true

module ContractManagement
  class BusinessDayCalculator
    def self.add(date, number_of_days)
      result = date
      number_of_days.times do
        result += 1.day
        result += 1.day while result.saturday? || result.sunday?
      end
      result
    end
  end
end
