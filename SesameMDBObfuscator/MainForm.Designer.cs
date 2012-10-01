namespace WindowsFormsApplication1
{
    partial class MainForm
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.saltEdit = new System.Windows.Forms.TextBox();
            this.label1 = new System.Windows.Forms.Label();
            this.label2 = new System.Windows.Forms.Label();
            this.mdbFileNameEdit = new System.Windows.Forms.TextBox();
            this.button1 = new System.Windows.Forms.Button();
            this.obfuscateButton = new System.Windows.Forms.Button();
            this.logTextBox = new System.Windows.Forms.TextBox();
            this.mdbFileOpenDialog = new System.Windows.Forms.OpenFileDialog();
            this.encodeTextBox = new System.Windows.Forms.TextBox();
            this.label3 = new System.Windows.Forms.Label();
            this.encodeButton = new System.Windows.Forms.Button();
            this.progressBar = new System.Windows.Forms.ProgressBar();
            this.SuspendLayout();
            // 
            // saltEdit
            // 
            this.saltEdit.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left)
                        | System.Windows.Forms.AnchorStyles.Right)));
            this.saltEdit.Location = new System.Drawing.Point(82, 40);
            this.saltEdit.Name = "saltEdit";
            this.saltEdit.Size = new System.Drawing.Size(292, 22);
            this.saltEdit.TabIndex = 3;
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(44, 43);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(32, 17);
            this.label1.TabIndex = 1;
            this.label1.Text = "Salt";
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(12, 15);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(64, 17);
            this.label2.TabIndex = 2;
            this.label2.Text = "MDB File";
            // 
            // mdbFileNameEdit
            // 
            this.mdbFileNameEdit.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left)
                        | System.Windows.Forms.AnchorStyles.Right)));
            this.mdbFileNameEdit.Location = new System.Drawing.Point(82, 12);
            this.mdbFileNameEdit.Name = "mdbFileNameEdit";
            this.mdbFileNameEdit.Size = new System.Drawing.Size(292, 22);
            this.mdbFileNameEdit.TabIndex = 1;
            this.mdbFileNameEdit.TextChanged += new System.EventHandler(this.mdbFileNameEdit_TextChanged);
            // 
            // button1
            // 
            this.button1.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Right)));
            this.button1.Location = new System.Drawing.Point(380, 12);
            this.button1.Name = "button1";
            this.button1.Size = new System.Drawing.Size(91, 23);
            this.button1.TabIndex = 2;
            this.button1.Text = "Browse";
            this.button1.UseVisualStyleBackColor = true;
            this.button1.Click += new System.EventHandler(this.button1_Click);
            // 
            // obfuscateButton
            // 
            this.obfuscateButton.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Right)));
            this.obfuscateButton.Enabled = false;
            this.obfuscateButton.Location = new System.Drawing.Point(380, 40);
            this.obfuscateButton.Name = "obfuscateButton";
            this.obfuscateButton.Size = new System.Drawing.Size(91, 23);
            this.obfuscateButton.TabIndex = 4;
            this.obfuscateButton.Text = "Obfuscate";
            this.obfuscateButton.UseVisualStyleBackColor = true;
            this.obfuscateButton.Click += new System.EventHandler(this.obfuscateButton_Click);
            // 
            // logTextBox
            // 
            this.logTextBox.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom)
                        | System.Windows.Forms.AnchorStyles.Left)
                        | System.Windows.Forms.AnchorStyles.Right)));
            this.logTextBox.Location = new System.Drawing.Point(12, 126);
            this.logTextBox.Multiline = true;
            this.logTextBox.Name = "logTextBox";
            this.logTextBox.ReadOnly = true;
            this.logTextBox.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.logTextBox.Size = new System.Drawing.Size(459, 231);
            this.logTextBox.TabIndex = 6;
            this.logTextBox.TabStop = false;
            // 
            // mdbFileOpenDialog
            // 
            this.mdbFileOpenDialog.DefaultExt = "mdb";
            this.mdbFileOpenDialog.Filter = "MDB files|*.mdb";
            // 
            // encodeTextBox
            // 
            this.encodeTextBox.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left)
                        | System.Windows.Forms.AnchorStyles.Right)));
            this.encodeTextBox.Location = new System.Drawing.Point(82, 68);
            this.encodeTextBox.Name = "encodeTextBox";
            this.encodeTextBox.Size = new System.Drawing.Size(292, 22);
            this.encodeTextBox.TabIndex = 7;
            this.encodeTextBox.TextChanged += new System.EventHandler(this.encodeTextBox_TextChanged);
            // 
            // label3
            // 
            this.label3.AutoSize = true;
            this.label3.Location = new System.Drawing.Point(31, 71);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(45, 17);
            this.label3.TabIndex = 8;
            this.label3.Text = "String";
            // 
            // encodeButton
            // 
            this.encodeButton.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Right)));
            this.encodeButton.Enabled = false;
            this.encodeButton.Location = new System.Drawing.Point(380, 68);
            this.encodeButton.Name = "encodeButton";
            this.encodeButton.Size = new System.Drawing.Size(91, 23);
            this.encodeButton.TabIndex = 9;
            this.encodeButton.Text = "Encode";
            this.encodeButton.UseVisualStyleBackColor = true;
            this.encodeButton.Click += new System.EventHandler(this.encodeButton_Click);
            // 
            // progressBar
            // 
            this.progressBar.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left)
                        | System.Windows.Forms.AnchorStyles.Right)));
            this.progressBar.Location = new System.Drawing.Point(12, 97);
            this.progressBar.Name = "progressBar";
            this.progressBar.Size = new System.Drawing.Size(458, 23);
            this.progressBar.Step = 1;
            this.progressBar.TabIndex = 10;
            // 
            // MainForm
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(8F, 16F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.AutoSizeMode = System.Windows.Forms.AutoSizeMode.GrowAndShrink;
            this.ClientSize = new System.Drawing.Size(485, 369);
            this.Controls.Add(this.progressBar);
            this.Controls.Add(this.encodeButton);
            this.Controls.Add(this.label3);
            this.Controls.Add(this.encodeTextBox);
            this.Controls.Add(this.logTextBox);
            this.Controls.Add(this.obfuscateButton);
            this.Controls.Add(this.button1);
            this.Controls.Add(this.mdbFileNameEdit);
            this.Controls.Add(this.label2);
            this.Controls.Add(this.label1);
            this.Controls.Add(this.saltEdit);
            this.MaximizeBox = false;
            this.Name = "MainForm";
            this.Text = "Sesame MDB Obfuscator";
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion

        private System.Windows.Forms.TextBox saltEdit;
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.TextBox mdbFileNameEdit;
        private System.Windows.Forms.Button button1;
        private System.Windows.Forms.Button obfuscateButton;
        private System.Windows.Forms.TextBox logTextBox;
        private System.Windows.Forms.OpenFileDialog mdbFileOpenDialog;
        private System.Windows.Forms.TextBox encodeTextBox;
        private System.Windows.Forms.Label label3;
        private System.Windows.Forms.Button encodeButton;
        private System.Windows.Forms.ProgressBar progressBar;
    }
}

