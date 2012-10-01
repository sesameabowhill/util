using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using System.IO;
using System.Data.OleDb;
using System.Security.Cryptography;

namespace WindowsFormsApplication1
{
    public partial class MainForm : Form
    {
        private static Random random = new Random((int)DateTime.Now.Ticks);
        private static char[] randomCharacters = new char[] { '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 
            'd', 'e', 'f', 'g', 'h', 'k', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 
            'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 
            'X', 'Y', 'Z', };

        private static int MAX_NAME_LENGTH = 12;

        private static MD5 md5Hash = MD5.Create();

        public MainForm()
        {
            InitializeComponent();
            saltEdit.Text = randomString(16);
        }

        private void button1_Click(object sender, EventArgs e)
        {
            DialogResult result = mdbFileOpenDialog.ShowDialog();
            if (result == DialogResult.OK)
            {
                mdbFileNameEdit.Text = mdbFileOpenDialog.FileName;
            }
            
        }
        private string randomString(int size)
        {
            StringBuilder builder = new StringBuilder();
            for (int i = 0; i < size; i++)
            {
                builder.Append(randomCharacters[Convert.ToInt32(Math.Floor(randomCharacters.Length * random.NextDouble()))]);
            }
            return builder.ToString();
        }

        private void mdbFileNameEdit_TextChanged(object sender, EventArgs e)
        {
            obfuscateButton.Enabled = File.Exists(mdbFileNameEdit.Text);
        }

        private void obfuscateButton_Click(object sender, EventArgs e)
        {
            string connectionString = @"Provider=Microsoft.ACE.OLEDB.12.0;Data Source=" + mdbFileNameEdit.Text + 
                ";Jet OLEDB:Database Password=password";

            OleDbConnection connection = new OleDbConnection(connectionString);
            connection.Open();

            log("open [" + mdbFileNameEdit.Text + "], salt [" + saltEdit.Text + "]");

            List<TableColumn> columns = new List<TableColumn>();
            columns.Add(new TableColumn("Addresses", "City", "ID"));
            columns.Add(new TableColumn("Addresses", "ID", "ID"));
            columns.Add(new TableColumn("Addresses", "Street", "ID"));
            columns.Add(new TableColumn("Appointments", "PatientID", "ID"));
            columns.Add(new TableColumn("EMails", "EMail", "ID"));
            columns.Add(new TableColumn("EMails", "OwnerName", "ID", MAX_NAME_LENGTH));
            columns.Add(new TableColumn("Offices", "AddressID", "ID"));
            columns.Add(new TableColumn("PatientEMailLinks", "EMailID", "ID"));
            columns.Add(new TableColumn("PatientEMailLinks", "PatientID", "ID"));
            columns.Add(new TableColumn("PatientPhoneLinks", "PatientID", "ID"));
            columns.Add(new TableColumn("PatientPhoneLinks", "PhoneID", "ID"));
            columns.Add(new TableColumn("PatientReferringLinks", "PatientID", "ID"));
            columns.Add(new TableColumn("PatientResponsibleLinks", "PatientID", "ID"));
            columns.Add(new TableColumn("PatientResponsibleLinks", "ResponsibleID", "ID"));
            columns.Add(new TableColumn("Patients", "AddressID", "ID"));
            columns.Add(new TableColumn("Patients", "FirstName", "ID", MAX_NAME_LENGTH));
            columns.Add(new TableColumn("Patients", "ID", "ID"));
            columns.Add(new TableColumn("Patients", "LastName", "ID", MAX_NAME_LENGTH));
            columns.Add(new TableColumn("PatientStaffLinks", "PatientID", "ID"));
            columns.Add(new TableColumn("Phones", "ID", "ID"));
            columns.Add(new TableColumn("Phones", "PhoneNumber", "ID"));
            columns.Add(new TableColumn("Recalls", "PatientID", "ID"));
            columns.Add(new TableColumn("Referrings", "Email", "ID"));
            columns.Add(new TableColumn("ResponsibleEMailLinks", "EMailID", "ID"));
            columns.Add(new TableColumn("ResponsibleEMailLinks", "ResponsibleID", "ID"));
            columns.Add(new TableColumn("ResponsiblePhoneLinks", "PhoneID", "ID"));
            columns.Add(new TableColumn("ResponsiblePhoneLinks", "ResponsibleID", "ID"));
            columns.Add(new TableColumn("Responsibles", "AddressID", "ID"));
            columns.Add(new TableColumn("Responsibles", "FirstName", "ID", MAX_NAME_LENGTH));
            columns.Add(new TableColumn("Responsibles", "ID", "ID"));
            columns.Add(new TableColumn("Responsibles", "LastName", "ID", MAX_NAME_LENGTH));
            columns.Add(new TableColumn("TreatmentPlans", "PatientID", "ID"));

            progressBar.Maximum = 0;
            progressBar.Maximum = columns.Count;
            progressBar.Value = 0;
            foreach (TableColumn tableColumn in columns)
            {
                progressBar.PerformStep();
                obfuscateTableColumn(tableColumn, saltEdit.Text, connection);
            }

            connection.Close();
            log("close [" + mdbFileNameEdit.Text + "]");
        }

        private void obfuscateTableColumn(TableColumn tableColumn, string salt, OleDbConnection connection)
        {
            log("reading [" + tableColumn + "]");
            OleDbCommand command = new OleDbCommand("SELECT [" + tableColumn.idColumn + "], [" + 
                tableColumn.column + "] FROM [" + tableColumn.table + "]", connection);

            OleDbDataReader objectReader = command.ExecuteReader();

            int count = 0;
            if (objectReader != null)
            {
                while (objectReader.Read())
                {
                    if (!objectReader.IsDBNull(0) && !objectReader.IsDBNull(1))
                    {
                        string id = objectReader.GetString(0);
                        string value = objectReader.GetString(1);

                        OleDbCommand updateCommand = new OleDbCommand("UPDATE [" + tableColumn.table + "] SET [" +
                             tableColumn.column + "] = ? WHERE [" + tableColumn.idColumn + "] = ?", connection);
                        string newValue = obfuscateString(value, salt);
                        if (tableColumn.maxLength > 0 && newValue.Length > tableColumn.maxLength)
                        {
                            newValue = newValue.Substring(0, tableColumn.maxLength);
                        }
                        updateCommand.Parameters.AddWithValue(tableColumn.column, newValue);
                        updateCommand.Parameters.AddWithValue(tableColumn.idColumn, id);
                        updateCommand.ExecuteNonQuery();
                        count++;
                    }
                }
                objectReader.Close();
            }
            log("[" + count + "] record" + (count == 1 ? "" : "s") + " encoded in [" + tableColumn + "]");
        }

        private string obfuscateString(string value, string salt)
        {
            if (string.IsNullOrEmpty(value))
            {
                return value;
            }
            else
            {
                byte[] data = md5Hash.ComputeHash(Encoding.UTF8.GetBytes(value + salt));

                StringBuilder output = new StringBuilder();
                for (int i = 0; i < data.Length; i++)
                {
                    output.Append(data[i].ToString("x2"));
                }
                return output.ToString();
            }
        }

        private void log(string message)
        {
            logTextBox.Text = logTextBox.Text + message + "\r\n";
            logTextBox.SelectionStart = logTextBox.Text.Length;
            logTextBox.ScrollToCaret();
        }

        private struct TableColumn
        {
            public string table, column, idColumn;
            public int maxLength;

            public TableColumn(string table, string column, string idColumn)
            {
                this.table = table;
                this.column = column;
                this.idColumn = idColumn;
                this.maxLength = 0;
            }

            public TableColumn(string table, string column, string idColumn, int maxLength)
            {
                this.table = table;
                this.column = column;
                this.idColumn = idColumn;
                this.maxLength = maxLength;
            }

            public override string ToString()
            {
                return table + "." + column;
            }
        }

        private void encodeButton_Click(object sender, EventArgs e)
        {
            encodeTextBox.Text = obfuscateString(encodeTextBox.Text, saltEdit.Text);
            encodeTextBox.Focus();
        }

        private void encodeTextBox_TextChanged(object sender, EventArgs e)
        {
            encodeButton.Enabled = ! string.IsNullOrEmpty(encodeTextBox.Text);
        }

    }

}
