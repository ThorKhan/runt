#!/usr/bin/env ruby

require 'date'
require 'runt/dateprecision'

#
# Author:: Matthew Lipper

module Runt

# Base class for all TemporalExpression classes that will probably be scuttled
# unless it proves itself useful in some fashion. Mostly a side-effect of many
# years working with statically typed languages.
#
# TemporalExpressions are inspired by the recurring event
# <tt>pattern</tt>[http://martinfowler.com/apsupp/recurring.pdf]
# described by Martin Fowler. Essentially, they provide a pattern language for
# specifying recurring events using set expressions.
class TemporalExpression
  # Returns true or false depending on whether this TemporalExpression includes the supplied
  # date expression.
  def include?(date_expr); false end
  def to_s; "TemporalExpression" end
end

# Base class for TemporalExpression classes that can be composed of other
# TemporalExpression objects imlpemented using the <tt>Composite(GoF)</tt> pattern.
class CollectionTE < TemporalExpression

  attr_reader :expressions
  protected :expressions

  def initialize
    @expressions = Array.new
  end

  def add(anExpression)
    @expressions.push anExpression
    self
  end

  def to_s; "CollectionTE" end
end

# Composite TemporalExpression that will be true if <b>any</b> of it's
# component expressions are true.
class UnionTE < CollectionTE

  def include?(aDate)
    @expressions.each do |expr|
      return true if expr.include?(aDate)
    end
    false
  end

  def to_s; "UnionTE" end
end

# Composite TemporalExpression that will be true only if <b>all</b> it's
# component expressions are true.
class IntersectionTE < CollectionTE

  def include?(aDate)
		#Handle @expressions.size==0
		result = false
    @expressions.each do |expr|
			return false unless (result = expr.include?(aDate))
    end
		result
  end

  def to_s; "IntersectionTE" end
end

# TemporalExpression that will be true only if the first of
# it's two contained expressions is true and the second is false.
class DifferenceTE < TemporalExpression

  def initialize(expr1, expr2)
    @expr1 = expr1
    @expr2 = expr2
  end

  def include?(aDate)
    return false unless (@expr1.include?(aDate) && !@expr2.include?(aDate))
    true
  end

  def to_s; "DifferenceTE" end
end

# TemporalExpression that provides for inclusion of an arbitrary date.
class ArbitraryTE < TemporalExpression

  def initialize(date_expr)
    @date_expr = date_expr
  end

  # Will return true if the supplied object is == to that which was used to
  # create this instance
  def include?(date_expr)
    return true if @date_expr == date_expr
    false
  end

  def to_s; "ArbitraryTE" end

end

# TemporalExpression that provides a thin wrapper around built-in Ruby <tt>Range</tt> functionality
# facilitating inclusion of an arbitrary range in a temporal expression.
#
#  See also: Range
class ArbitraryRangeTE < TemporalExpression

  def initialize(date_expr)
		raise TypeError, 'expected range' unless date_expr.kind_of?(Range)
    @date_expr = date_expr
  end

	# Will return true if the supplied object is included in the range used to
  # create this instance
  def include?(date_expr)
		return @date_expr.include?(date_expr)
  end

  def to_s; "ArbitraryRangeTE" end
end

class DayInMonthTE < TemporalExpression

  def initialize(offset, day_index)
    @day_index = day_index
    @offset = offset
  end

  def include?(date)
    ( day_matches?(date) ) && ( week_matches?(date) )
  end

  def day_matches?(date)
    @day_index == date.wday
  end

  def week_matches?(date)
    if(@offset > 0)
      return week_from_start_matches?(date)
    else
      return week_from_end_matches?(date)
    end
  end

  def week_from_start_matches?(date)
    week_in_month(date.day)==@offset
  end

  def week_from_end_matches?(date)
    n = days_left_in_month(date) + 1
    week_in_month(n) == @offset.abs
  end

  def week_in_month(day_in_month)
    ((day_in_month - 1) / 7) + 1
  end

  def days_left_in_month(date)
    return max_day_of_month(date) - date.day
  end

  def max_day_of_month(date)
    result = 1
    date.step( Date.new(date.year,date.mon+1,1), 1 ){ |d| result=d.day unless d.day < result }
    result
  end

  def to_s
    "DayInMonthTE"
  end

  def print(date)
    puts "DayInMonthTE: #{date}"
    puts "include? == #{include?(date)}"
    puts "day_matches? == #{day_matches?(date)}"
    puts "week_matches? == #{week_matches?(date)}"
    puts "week_from_start_matches? == #{week_from_start_matches?(date)}"
    puts "week_from_end_matches? == #{week_from_end_matches?(date)}"
    puts "days_left_in_month == #{days_left_in_month(date)}"
    puts "max_day_of_month == #{max_day_of_month(date)}"
  end
end

class RangeEachYearTE < TemporalExpression

  def initialize(start_month, start_day=0, end_month=start_month, end_day=0)
    super()
    @start_month = start_month
    @start_day = start_day
    @end_month = end_month
    @end_day = end_day
  end

  def include?(date)
    months_include?(date) ||
      start_month_include?(date) ||
        end_month_include?(date)
  end

  def to_s
    "RangeEachYearTE"
  end

  def print(date)
    puts "DayInMonthTE: #{date}"
    puts "include? == #{include?(date)}"
    puts "months_include? == #{months_include?(date)}"
    puts "end_month_include? == #{end_month_include?(date)}"
    puts "start_month_include? == #{start_month_include?(date)}"
  end

	private
  def months_include?(date)
    (date.mon > @start_month) && (date.mon < @end_month)
  end

  def end_month_include?(date)
    return false unless (date.mon == @end_month)
    (@end_day == 0)  || (date.day <= @end_day)
  end

  def start_month_include?(date)
    return false unless (date.mon == @start_month)
    (@start_day == 0) || (date.day >= @start_day)
  end
end

class RangeEachDayTE < TemporalExpression

  CURRENT=28
  NEXT=29
  ANY_DATE=TimePoint.day_of_month(2002,8,CURRENT)

  def initialize(start_hour, start_minute, end_hour, end_minute)

    start_time = TimePoint.minute(ANY_DATE.year,ANY_DATE.month,
              ANY_DATE.day,start_hour,start_minute)

    if(@spans_midnight = spans_midnight?(start_hour, end_hour)) then
      end_time = get_next(end_hour,end_minute)
    else
      end_time = get_current(end_hour,end_minute)
    end

    @range = start_time..end_time
  end

  def include?(date)
		raise TypeError, 'expected date' unless date.kind_of?(Date)

    if(@spans_midnight&&date.hour<12) then
      #Assume next day
      return @range.include?(get_next(date.hour,date.min))
    end

    #Same day
    return @range.include?(get_current(date.hour,date.min))
  end


  def to_s
    "RangeEachDayTE"
  end


  def print(date)
    puts "DayInMonthTE: #{date}"
    puts "include? == #{include?(date)}"
  end

  def spans_midnight?(start_hour, end_hour)
    return end_hour <= start_hour
  end

  private
  def get_current(hour,minute)
      TimePoint.minute(ANY_DATE.year,ANY_DATE.month,CURRENT,hour,minute)
  end

  def get_next(hour,minute)
      TimePoint.minute(ANY_DATE.year,ANY_DATE.month,NEXT,hour,minute)
  end

end

end
