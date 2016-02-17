package github.msf;

import java.io.Console;

public class InterestCalc {

    public double _initialAmount;
    public double _interestRate;
    public double _periodicContribution;
    public double _contributionIncreaseRatePerRound;
    public double _contributionsPerRound;
    public int _computeRounds;

    public double _totalAmount;
    public double _totalInterest;

    public InterestCalc(
            int initialAmount, double interestRate, int periodicContribution, double periodicIncreaseRate,
            int contributionsPerYear, int years)
    {
        _initialAmount = initialAmount;
        _interestRate = interestRate;
        _periodicContribution = periodicContribution;
        _contributionIncreaseRatePerRound = periodicIncreaseRate;
        _contributionsPerRound = contributionsPerYear;
        _computeRounds = years;

        _totalAmount = _initialAmount;
        _totalInterest = 0;
    }

    public double GetTotal() {
        for(int j = 0; j < _computeRounds; j++) {
            PrintDebug(j);
            for(int i = 0; i < _contributionsPerRound; i++) {
                double interest = _totalAmount * (_interestRate/_contributionsPerRound);
                _totalInterest += interest;
                _totalAmount += interest;
                _totalAmount += _periodicContribution;
            }

            double tmp = _contributionsPerRound * _contributionIncreaseRatePerRound;
            _contributionsPerRound += tmp;
        }
        double contrib = _totalAmount - _totalInterest;
        System.out.printf("Gains: %.2f%%\n", _totalInterest/contrib * 100);
        return _totalAmount;
    }


    public void PrintDebug(int round) {

        StringBuilder sb = new StringBuilder();
        sb.append(round).append(": ");
        sb.append("total: ").append(String.format("%7.2f", _totalAmount)).append("\t");
        sb.append("interest: ").append(String.format("%7.2f", _totalInterest)).append("\t");
        sb.append("contrib: ").append(String.format("%7.2f", _totalAmount - _totalInterest)).append("\t");
        sb.append("contrib/y: ").append(String.format("%7.2f", _periodicContribution * _contributionsPerRound));
        sb.append("\n");

        System.out.print(sb.toString());
    }


    public static void Main(String[] args) {
        while(true) {
            Console c = System.console();
            String yearsStr = c.readLine("Years: ");
            String rateStr = c.readLine("InterestRate in percentage: ");
            String initial = c.readLine("Initial amount: ");
            String contrib = c.readLine("Contribution amount: ");
            String contribRate = c.readLine("Contrib. increase rate per round: ");
            String contPeriod = c.readLine("How many contributions per year (12?, 6?, 4? 2?): ");

            InterestCalc calc = new InterestCalc(
                    Integer.parseInt(initial),
                    Double.parseDouble(rateStr)/100.0,
                    Integer.parseInt(contrib),
                    Double.parseDouble(contribRate)/100.0,
                    Integer.parseInt(contPeriod),
                    Integer.parseInt(yearsStr));

            calc.GetTotal();
        }
    }
}
