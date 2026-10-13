using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Xepa.Api.Entities;

namespace Xepa.Api.Data.Configurations;

/// <summary>Colunas do tipo complexo Endereco, reaproveitadas por toda tabela que guarda um endereço.</summary>
internal static class EnderecoMapeamento
{
    public static void Configurar(ComplexPropertyBuilder<Endereco> endereco, string prefixo = "")
    {
        endereco.Property(e => e.Cep).HasColumnName(prefixo + "Cep").HasMaxLength(8).IsFixedLength();
        endereco.Property(e => e.Logradouro).HasColumnName(prefixo + "Logradouro").HasMaxLength(150);
        endereco.Property(e => e.Numero).HasColumnName(prefixo + "Numero").HasMaxLength(20);
        endereco.Property(e => e.Complemento).HasColumnName(prefixo + "Complemento").HasMaxLength(100);
        endereco.Property(e => e.Bairro).HasColumnName(prefixo + "Bairro").HasMaxLength(80);
        endereco.Property(e => e.Cidade).HasColumnName(prefixo + "Cidade").HasMaxLength(80);
        endereco.Property(e => e.Uf).HasColumnName(prefixo + "Uf").HasMaxLength(2).IsFixedLength();
        endereco.Property(e => e.Latitude).HasColumnName(prefixo + "Latitude");
        endereco.Property(e => e.Longitude).HasColumnName(prefixo + "Longitude");
    }
}
