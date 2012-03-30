pro close_device, pdf=pdf, delete=delete

  closedevice

  if not keyword_set(pdf) then return

  ; Default convert command
  Convert = 'ps2pdf'

  ; Check if pdf is a string or a number
  siz = size(pdf)
  if siz(1) eq 7 then Convert = pdf

  ; Convert PS/EPS file to PDF and remove original if required
  common SETDEVICE, NameFile
  PdfFile = NameFile
  i = strpos(PdfFile,'.',/reverse_search)
  PdfFile = strmid(PdfFile, 0, i) + '.pdf'
  Command = Convert + ' ' + NameFile + ' ' + PdfFile
  if keyword_set(delete) then Command = Command + '; /bin/rm ' + NameFile

  print,'Command = ', Command

  spawn, Command

end
