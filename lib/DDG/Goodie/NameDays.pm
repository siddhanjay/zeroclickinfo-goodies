package DDG::Goodie::NameDays;
# ABSTRACT: Display Name Days for a given name or date

use utf8;
use strict;
use DateTime;
use DDG::Goodie;
with 'DDG::GoodieRole::Dates';

zci answer_type => "name_days_w25";
zci is_cached   => 1;

# Metadata
name "Name Days";
source "https://en.wikipedia.org/wiki/Name_days_in_Poland";
description "Name Days for a given name or date";
primary_example_queries "name day Maria", "1 June name day";
secondary_example_queries "name days today", "imieniny 9 stycznia", "imieniny Marii";
category "dates";
topics "social", "everyday";
code_url "https://github.com/duckduckgo/zeroclickinfo-goodies/blob/master/lib/DDG/Goodie/NameDays/W25/W25.pm";
attribution github => ["http://github.com/W25", "W25"];

# Triggers
triggers any => "name day", "name days", "nameday", "namedays", "imieniny", "jmeniny", "svátek";



# Load the data file
my @names = (); # Names indexed by day
my %dates = (); # Days indexed by name

# File format: 366 lines (one for each day of a year).
# Each line contains names separated with a space.
# A line may contain the names in genitive case or variations of a name.
# These variations are placed after vertical bar character (|); they are
# not shown when searching for this day, but you can search for them.

sub load_days_file {
    my $file_name = shift();
    
    my @lines = share($file_name)->slurp(iomode => '<:encoding(UTF-8)');
    
    $file_name =~ s/\.txt$//;
    
    die "The text file must include 366 lines" unless scalar(@lines) == 366;

    my $day_of_year = 1;

    # Read names for each day and add them to the hash
    for (@lines) {
        # Add all names, including the names after vertical bar
        my $names_for_date = lc($_);
        $names_for_date =~ s/\|/ /;
        for my $name (split(' ', $names_for_date)) {
            push(@{$dates{$name}}, $file_name . '|' . $day_of_year);
        }
    
        # Remove the names after vertical bar (|)
        chomp;
        s/\s*\|.*$//;
        if ($_) {
            $names[$day_of_year - 1] .= "; " if ($names[$day_of_year - 1]);
            $names[$day_of_year - 1] .= $file_name . ': ' . $_;
        }
        
        # Advance to the next day
        $day_of_year++;
    }
}

sub finish_loading {
    # Convert the dates to string
    for (keys %dates) {
        # Group the dates by country
        my %dates_by_country = ();
        foreach (@{$dates{$_}}) {
            die 'Internal error' unless /^(.*?)\|(\d+)$/;
            # Any leap year here, because the text file includes February, 29
            my $d = DateTime->from_day_of_year(year => 2000, day_of_year => $2);
            if (exists $dates_by_country{$1}) {
                $dates_by_country{$1} .= ', ';
            }
            $dates_by_country{$1} .= $d->strftime('%e %b');
        }
        
        # Convert to string
        my $res = '';
        foreach (sort keys %dates_by_country) {
            $res .= $_ . ': ' . $dates_by_country{$_} . "; ";
        }
        
        $res =~ s/; $//;
        $dates{$_} = $res;
    }
}


load_days_file('Czech Republic.txt');
load_days_file('Hungary.txt');
load_days_file('Poland.txt');
finish_loading();


sub parse_other_date_formats {
    # Quick fix for the date formats not supported by parse_datestring_to_date.
    # If parse_datestring_to_date will be improved, you can remove some of the following code.
    
    # US date format ("month/day")
    if (/^([0-1]?[0-9])\s?\/\s?([0-3]?[0-9])$/) {
        # Suppress errors for invalid dates with eval
        return eval { new DateTime(year => 2000, day => $2, month => $1) };
    }
    
    # Polish date format ("day.month")
    if (/^([0-3]?[0-9])\s?\.\s?([0-1]?[0-9])$/) {
        return eval { new DateTime(year => 2000, day => $1, month => $2) };
    }
        
    # Polish month names
    s/\b(styczeń|stycznia)\b/Jan/i;
    s/\b(luty|lutego)\b/Feb/i;
    s/\b(marzec|marca)\b/Mar/i;
    s/\b(kwiecień|kwietnia)\b/Apr/i;
    s/\b(maj|maja)\b/May/i;
    s/\b(czerwiec|czerwca)\b/Jun/i;
    s/\b(lipiec|lipca)\b/Jul/i;
    s/\b(sierpień|sierpnia)\b/Aug/i;
    s/\b(wrzesień|września)\b/Sep/i;
    s/\b(październik|października)\b/Oct/i;
    s/\b(listopad|listopada)\b/Nov/i;
    s/\b(grudzień|grudnia)\b/Dec/i;
    
    # Czech month names
    s/\b(leden|ledna)\b/Jan/i;
    s/\b(únor|února)\b/Feb/i;
    s/\b(březen|března)\b/Mar/i;
    s/\b(duben|dubna)\b/Apr/i;
    s/\b(květen|května)\b/May/i;
    s/\b(červen|června)\b/Jun/i;
    s/\b(červenec|července)\b/Jul/i;
    s/\b(srpen|srpna)\b/Aug/i;
    s/\b(září)\b/Sep/i;
    s/\b(říjen|října)\b/Oct/i;
    s/\b(listopad|listopadu)\b/Nov/i;
    s/\b(prosinec|prosince)\b/Dec/i;
    
    # Parse_datestring_to_date uses the current year if the year is not specified, so
    # it will not parse "29 Feb" in a non-leap year. Fix this problem here.
    if (/^29\s?(?:th)?\s*(Feb|February)/ || /(Feb|February)\s*29\s?(?:th)?$/) {
        return new DateTime(year => 2000, day => 29, month => 2);
    }
    
    return parse_datestring_to_date($_);
}



# Handle statement
handle remainder => sub {
    # Search by name first
    if (exists $dates{lc($_)}) {
        return $dates{lc($_)};
    }
    
    # Then, search by date
    my $day = parse_datestring_to_date($_);
    
    if (!$day) {
        $day = parse_other_date_formats($_);
    }
    
    return unless $day;
    
    # Any leap year here, because the array includes February, 29
    $day->set_year(2000);
    
    return $names[$day->day_of_year() - 1];
};

1;
