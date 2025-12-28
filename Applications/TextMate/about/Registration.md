Title: Registration

# 注册

<script>
var licensees = TextMate.licensees;
if(licensees) { document.write("此版本应用注册到 " + licensees + "."); }
else          { document.write("此版本应用未注册 <a href='#' onClick='javascript:TextMate.addLicense();'>添加许可证</a>"); }
</script>
