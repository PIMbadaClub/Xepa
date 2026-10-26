namespace Xepa.Domain;

/// <summary>Raio e taxa de entrega (RN07).</summary>
public static class RegrasEntrega
{
    public const double RaioMaximoKm = 5;
    public const decimal TaxaFixa = 3.00m;
    public const decimal TaxaPorKm = 1.50m;

    public static decimal CalcularTaxa(double distanciaKm)
    {
        if (distanciaKm > RaioMaximoKm)
            throw new RegraDeNegocioException($"Entrega disponível só até {RaioMaximoKm} km da loja. Escolha a retirada.");

        return decimal.Round(TaxaFixa + TaxaPorKm * (decimal)distanciaKm, 2, MidpointRounding.AwayFromZero);
    }
}
